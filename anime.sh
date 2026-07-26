#!/bin/sh
# API adapter for the current ani-cli scraping and decryption flow.
#
# Usage:
#   ./anime.sh /search "query=one+piece"
#   ./anime.sh /episodes/<show_id> "mode=sub"
#   ./anime.sh /episode_url "show_id=<show_id>&ep_no=1&quality=best&mode=sub"

agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:150.0) Gecko/20100101 Firefox/150.0"
allanime_cdn="https://cdn.mkissa.net/all/mk/_app/immutable"
allanime_refr="https://mkissa.to"
allanime_base="allanime.day"
allanime_api="https://api.mkissa.net"
allanime_query_hash="f4662f4b7510b26795dd53ef824a0bf1740fbbc5d1273fab18222ac831bca8d0"
app_base_url="${APP_BASE_URL:-}"

mode="${ANI_CLI_MODE:-sub}"
quality="${ANI_CLI_QUALITY:-best}"
allanime_cookie="${ALLANIME_COOKIE:-${ANI_CLI_COOKIE:-}}"
LC_ALL=C
export LC_ALL

die() {
    # Keep the existing API error format used by app.py.
    printf '{"error":"%s"}\n' "$(printf '%s' "$1" | sed 's/[\\"]/\\&/g')"
    exit 1
}

dep_ch_failover() {
    [ -z "$1" ] && return 1
    prog=$(printf '%s' "$1" | cut -d, -f1)
    rest=$(printf '%s' "$1" | cut -s -d, -f2-)
    command -v "$prog" >/dev/null 2>&1 && printf '%s' "$prog" && return 0
    dep_ch_failover "$rest"
}

dep_ch() {
    command -v "$1" >/dev/null 2>&1 || die "Program $1 not found"
}

botan_exe=$(dep_ch_failover "botan3,botan,botan-cli") || die 'Program "botan" not found'
botan_version=$($botan_exe --version | cut -c1)

json_escape() {
    # The API query is JSON embedded in a shell string.
    printf '%s' "$1" | sed 's/[\\"]/\\&/g'
}

api_post() {
    if [ -n "$allanime_cookie" ]; then
        curl -b "$allanime_cookie" -e "$allanime_refr" -sS \
            -H "Content-Type: application/json" -X POST "${allanime_api}/api" \
            --data "$1" -A "$agent"
    else
        curl -e "$allanime_refr" -sS \
            -H "Content-Type: application/json" -X POST "${allanime_api}/api" \
            --data "$1" -A "$agent"
    fi
}

# ------------------------------
# SCRAPING AND DECRYPTION
# ------------------------------

get_links() {
    case "$*" in
        *[Mm][Pp]4upload*)
            episode_link=$(curl --max-time 10 -sLk "$*" -A "$agent" -e "$allanime_refr" |
                sed -nE 's|.*src: "([^"]*)"[[:space:]]*|Mp4Upload >\1|p')
            ;;
        *tools.fast4speed.rsvp*)
            episode_link=$(printf '%s\n' "Yt >$*")
            ;;
        *)
            case "$*" in
                http://*|https://*) source_url=$* ;;
                *) source_url="https://${allanime_base}$*" ;;
            esac
            response=$(curl -e "$allanime_refr" -sS "$source_url" -A "$agent")
            episode_link=$(printf '%s' "$response" | sed 's|},{|\
|g' | sed -nE \
                's|.*link":"([^"]*)".*"resolutionStr":"([^"]*)".*|\2 >\1|p;s|.*hls","url":"([^"]*)".*"hardsub_lang":"en-US".*|\1|p')
            ;;
    esac

    case "$episode_link" in
        *repackager.wixmp.com*)
            extract_link=$(printf '%s' "$episode_link" | cut -d'>' -f2 |
                sed 's|repackager.wixmp.com/||g;s|\.urlset.*||g')
            for j in $(printf '%s' "$episode_link" | sed -nE 's|.*/,([^/]*),/mp4.*|\1|p' | sed 's|,|\
|g'); do
                printf '%s >%s\n' "$j" "$extract_link" | sed "s|,[^/]*|${j}|g"
            done | sort -nr
            ;;
        *master.m3u8*)
            m3u8_refr=$(printf '%s' "$response" | sed -nE 's|.*Referer":"([^"]*)".*|\1|p')
            # This metadata is useful to the player in ani-cli, but is not a
            # playable result for this API. select_quality filters it below.
            [ -n "$m3u8_refr" ] && printf '%s\n' "m3u8_refr >$m3u8_refr"
            extract_link=$(printf '%s' "$episode_link" | head -1 | cut -d'>' -f2)
            relative_link=$(printf '%s' "$extract_link" | sed 's|[^/]*$||')
            m3u8_streams=$(curl -e "$m3u8_refr" -sS "$extract_link" -A "$agent")
            printf '%s' "$m3u8_streams" | grep -q "EXTM3U" &&
                printf '%s' "$m3u8_streams" | sed 's|^#EXT-X-STREAM.*x||g; s|,.*|p|g; /^#/d; $!N; s|\n| >|;/EXT-X-I-FRAME/d' |
                sed "s|>|>${relative_link}|g" | sort -nr
            ;;
        *) [ -n "$episode_link" ] && printf '%s\n' "$episode_link" ;;
    esac
}

# Provider decoding aligned with the current ani-cli provider protocol.
provider_init() {
    provider_name=$1
    provider_id=$(printf '%s' "$resp" | sed -n "$2" | head -1 | cut -d: -f2-)
    printf '%s' "$provider_id" | grep -qE '^--' && provider_id=$(printf '%s' "$provider_id" |
        sed 's/../&\
/g' |
        sed 's/^--$/\n/g;s/^79$/A/g;s/^7a$/B/g;s/^7b$/C/g;s/^7c$/D/g;s/^7d$/E/g;s/^7e$/F/g;s/^7f$/G/g;s/^70$/H/g;s/^71$/I/g;s/^72$/J/g;s/^73$/K/g;s/^74$/L/g;s/^75$/M/g;s/^76$/N/g;s/^77$/O/g;s/^68$/P/g;s/^69$/Q/g;s/^6a$/R/g;s/^6b$/S/g;s/^6c$/T/g;s/^6d$/U/g;s/^6e$/V/g;s/^6f$/W/g;s/^60$/X/g;s/^61$/Y/g;s/^62$/Z/g;s/^59$/a/g;s/^5a$/b/g;s/^5b$/c/g;s/^5c$/d/g;s/^5d$/e/g;s/^5e$/f/g;s/^5f$/g/g;s/^50$/h/g;s/^51$/i/g;s/^52$/j/g;s/^53$/k/g;s/^54$/l/g;s/^55$/m/g;s/^56$/n/g;s/^57$/o/g;s/^48$/p/g;s/^49$/q/g;s/^4a$/r/g;s/^4b$/s/g;s/^4c$/t/g;s/^4d$/u/g;s/^4e$/v/g;s/^4f$/w/g;s/^40$/x/g;s/^41$/y/g;s/^42$/z/g;s/^08$/0/g;s/^09$/1/g;s/^0a$/2/g;s/^0b$/3/g;s/^0c$/4/g;s/^0d$/5/g;s/^0e$/6/g;s/^0f$/7/g;s/^00$/8/g;s/^01$/9/g;s/^15$/-/g;s/^16$/./g;s/^67$/_/g;s/^46$/~/g;s/^02$/:/g;s/^17$/\//g;s/^07$/?/g;s/^1b$/#/g;s/^63$/\[/g;s/^65$/\]/g;s/^78$/@/g;s/^19$/!/g;s/^1c$/\$/g;s/^1e$/\&/g;s/^10$/\(/g;s/^11$/\)/g;s/^12$/*/g;s/^13$/+/g;s/^14$/,/g;s/^03$/;/g;s/^05$/=/g;s/^1d$/%/g' |
        tr -d '\n' | sed 's|/clock|/clock.json|g')
}

generate_link() {
    case $1 in
        1) provider_init "wixmp" "/^Default :/p" ;;
        2) provider_init "youtube" "/^Yt-mp4 :/p" ;;
        3) provider_init "sharepoint" "/^S-mp4 :/p" ;;
        # Do not let Luf-Mp4 match this plain Mp4 provider.
        4) provider_init "mp4upload" "/^Mp4 :/p" ;;
        *) true ;;
    esac
    [ -n "$provider_id" ] && get_links "$provider_id"
}

generate_link_from_source() {
    provider_name=${1%%:*}
    provider_id=${1#*:}
    provider_name=$(printf '%s' "$provider_name" | sed 's/[[:space:]]*$//')
    provider_id=$(printf '%s' "$provider_id" | sed 's/^[[:space:]]*//')
    [ -n "$provider_id" ] && get_links "$provider_id"
}

select_quality() {
    playable_links=$(printf '%s' "$links" | sed '/^m3u8_refr >/d')
    case "$1" in
        best) result=$(printf '%s' "$playable_links" | head -n1) ;;
        worst) result=$(printf '%s' "$playable_links" | grep -E '^[0-9]{3,4}' | tail -n1) ;;
        *) result=$(printf '%s' "$playable_links" | grep -m1 "$1") ;;
    esac
    [ -z "$result" ] && result=$(printf '%s' "$playable_links" | head -n1)

    case "$result" in
        *mp4upload*) refr_flag="--referrer=https://www.mp4upload.com/" ;;
        *sharepoint*) unset refr_flag ;;
        *) refr_flag="--referrer=$allanime_refr" ;;
    esac
    episode=$(printf '%s' "$result" | cut -d'>' -f2)
}

link_referer() {
    case "$1" in
        *mp4upload*) printf '%s' 'https://www.mp4upload.com/' ;;
        *sharepoint*) return 0 ;;
        *) printf '%s' "$allanime_refr" ;;
    esac
}

link_headers_json() {
    referer=$(link_referer "$1")
    if [ -n "$referer" ]; then
        printf '{"Referer":"%s"}' "$(json_escape "$referer")"
    else
        printf '{}'
    fi
}

player_json() {
    referer=$(link_referer "$episode")
    if [ -n "$referer" ]; then
        printf '{"url":"%s","headers":{"Referer":"%s"},"mpv_args":["--http-header-fields=Referer: %s","--referrer=%s"]}' \
            "$(json_escape "$episode")" \
            "$(json_escape "$referer")" \
            "$(json_escape "$referer")" \
            "$(json_escape "$referer")"
    else
        printf '{"url":"%s","headers":{},"mpv_args":[]}' "$(json_escape "$episode")"
    fi
}

player_url_value() {
    if [ -n "$app_base_url" ] && [ -n "$episode_referer" ]; then
        printf '%s/stream?url=%s&referer=%s' \
            "${app_base_url%/}" \
            "$(json_escape "$episode" | sed 's/%/%25/g; s/ /%20/g')" \
            "$(json_escape "$episode_referer" | sed 's/%/%25/g; s/ /%20/g')"
    else
        printf '%s' "$episode"
    fi
}

links_json() {
    printf '%s\n' "$playable_links" | while IFS= read -r link; do
        [ -n "$link" ] || continue
        label=${link%%>*}
        url=${link#*>}
        [ "$url" = "$link" ] && continue
        headers=$(link_headers_json "$url")
        printf '{"label":"%s","url":"%s","headers":%s}\n' \
            "$(json_escape "$label")" \
            "$(json_escape "$url")" \
            "$headers"
    done | sed '/^$/d' | paste -sd, -
}

sources_json() {
    printf '%s\n' "$resp" | while IFS= read -r source; do
        [ -n "$source" ] || continue
        label=${source%%:*}
        url=${source#*:}
        [ "$url" = "$source" ] && continue
        printf '{"label":"%s","url":"%s"}\n' \
            "$(json_escape "$(printf '%s' "$label" | sed 's/[[:space:]]*$//')")" \
            "$(json_escape "$(printf '%s' "$url" | sed 's/^[[:space:]]*//')")"
    done | sed '/^$/d' | paste -sd, -
}

fetch_keys() {
    page=$(mktemp) || return 1
    curl -sS -A "$agent" "$allanime_refr" -o "$page" 2>/dev/null || {
        rm -f "$page"
        return 1
    }

    allanime_epoch=$(sed -nE 's|.*"epoch":([0-9]+).*|\1|p' "$page")
    aa_part_b=$(sed -nE 's|.*"partB":"([^"]*)".*|\1|p' "$page")
    app_url=$(grep -oE "${allanime_cdn}/entry/app\.[A-Za-z0-9_.-]+\.js" "$page" | head -1)
    [ -n "$allanime_epoch" ] && [ -n "$aa_part_b" ] && [ -n "$app_url" ] || {
        rm -f "$page"
        return 1
    }

    urls=
    chunks=$(curl -sS -A "$agent" "$app_url" |
        grep -oE '"\.\./chunks/[A-Za-z0-9_.-]+\.js"' | tr -d '"' | head -5)
    for chunk in $chunks; do
        urls="$urls ${allanime_cdn}/${chunk#../}"
    done
    [ -n "$urls" ] || {
        rm -f "$page"
        return 1
    }

    js=$(mktemp) || {
        rm -f "$page"
        return 1
    }
    # shellcheck disable=SC2086
    curl -sS --parallel -A "$agent" $urls >"$js" 2>/dev/null
    aa_mask_hex=$(grep -oE '[0-9a-f]{64}' "$js" | head -1)
    rm -f "$js" "$page"
    [ -n "$aa_mask_hex" ] || return 1

    part_b_hex=$(printf '%s' "$aa_part_b" | b64_decode | od -An -tx1 | tr -d ' \n')
    [ -n "$part_b_hex" ] || return 1
    allanime_key=
    i=1
    while [ "$i" -le 64 ]; do
        m_byte="0x$(printf '%s' "$aa_mask_hex" | cut -c "$i"-$((i + 1)))"
        p_byte="0x$(printf '%s' "$part_b_hex" | cut -c "$i"-$((i + 1)))"
        res_dec=$((m_byte ^ p_byte))
        allanime_key="${allanime_key}$(printf '%02x' "$res_dec")"
        i=$((i + 2))
    done
    [ "${#allanime_key}" -eq 64 ]
}

b64_decode() {
    if base64 -d </dev/null >/dev/null 2>&1; then
        base64 -d
    else
        base64 -D
    fi
}

process_tobeparsed() {
    if ! printf '%s' "$1" | grep -q '"tobeparsed"'; then
        printf '%s' "$1"
        return 0
    fi

    tmp=$(mktemp) || return 1
    printf '%s' "$1" | sed -nE 's|.*"tobeparsed":"([^"]*)".*|\1|p' | b64_decode >"$tmp"
    file_size=$(wc -c <"$tmp")
    iv=$(dd if="$tmp" bs=1 skip=1 count=12 2>/dev/null | od -A n -tx1 | tr -d ' \n')
    gcm_len=$((file_size - 13))
    if [ "$botan_version" -eq 3 ]; then
        plain=$(dd if="$tmp" bs=1 skip=13 count="$gcm_len" 2>/dev/null |
            "$botan_exe" cipher --decrypt --cipher='AES-256/GCM' --key="$allanime_key" --nonce="$iv" - 2>/dev/null)
    else
        plain=$(dd if="$tmp" bs=1 skip=13 count="$gcm_len" 2>/dev/null |
            "$botan_exe" encryption --decrypt --mode='aes-256-gcm' --key="$allanime_key" --iv="$iv" 2>/dev/null)
    fi
    rm -f "$tmp"
    printf '%s' "$plain"
}

get_aa_req() {
    ts=$(($(date +%s) / 300 * 300 * 1000))
    payload_iv="$allanime_epoch:$allanime_query_hash:$ts"
    payload="{\"v\":1,\"ts\":$ts,\"epoch\":$allanime_epoch,\"qh\":\"$allanime_query_hash\"}"
    tmpdir=$(mktemp -d) || return 1

    printf '%s' "$payload_iv" | "$botan_exe" hash --no-fsname | "$botan_exe" hex_dec - |
        dd bs=1 count=12 of="$tmpdir/iv.bin" 2>/dev/null
    iv_hex=$(od -An -tx1 "$tmpdir/iv.bin" | tr -d ' \n')
    if [ "$botan_version" -eq 3 ]; then
        printf '%s' "$payload" | "$botan_exe" cipher --cipher=AES-256/GCM --key="$allanime_key" --nonce="$iv_hex" - >"$tmpdir/gcm_out.bin"
    else
        printf '%s' "$payload" | "$botan_exe" encryption --mode=aes-256-gcm --key="$allanime_key" --iv="$iv_hex" >"$tmpdir/gcm_out.bin"
    fi

    file_size=$(wc -c <"$tmpdir/gcm_out.bin")
    ct_len=$((file_size - 16))
    dd if="$tmpdir/gcm_out.bin" of="$tmpdir/ct.bin" bs=1 skip=0 count="$ct_len" 2>/dev/null
    dd if="$tmpdir/gcm_out.bin" of="$tmpdir/tag.bin" bs=1 skip="$ct_len" count=16 2>/dev/null
    result=$( {
        printf '\001'
        cat "$tmpdir/iv.bin" "$tmpdir/ct.bin" "$tmpdir/tag.bin"
    } | base64 | tr -d '\n')
    rm -rf "$tmpdir"
    printf '%s' "$result"
}

# ------------------------------
# API OPERATIONS
# ------------------------------

search_anime() {
    search_gql='query( $search: SearchInput $limit: Int $page: Int $translationType: VaildTranslationTypeEnumType $countryOrigin: VaildCountryOriginEnumType ) { shows( search: $search limit: $limit page: $page translationType: $translationType countryOrigin: $countryOrigin ) { edges { _id name availableEpisodes airedStart __typename } }}'
    escaped_query=$(json_escape "$query")
    escaped_gql=$(json_escape "$search_gql")
    api_resp=$(api_post "{\"variables\":{\"search\":{\"allowAdult\":false,\"allowUnknown\":false,\"query\":\"$escaped_query\"},\"limit\":40,\"page\":1,\"translationType\":\"$mode\",\"countryOrigin\":\"ALL\"},\"query\":\"$escaped_gql\"}") || die "Search request failed"
    printf '%s' "$api_resp" | sed 's|Show|\
|g' | sed -nE \
        's|.*_id":"([^"]*)","name":"([^"]*)".*"availableEpisodes":\{"sub":([0-9]+),"dub":([0-9]+).*|\1\t\2\t\3\t\4|p' |
        sed 's/\\"//g'
}

episodes_list() {
    episodes_list_gql='query ($showId: String!) { show( _id: $showId ) { _id availableEpisodesDetail }}'
    escaped_gql=$(json_escape "$episodes_list_gql")
    escaped_id=$(json_escape "$1")
    api_resp=$(api_post "{\"variables\":{\"showId\":\"$escaped_id\"},\"query\":\"$escaped_gql\"}") || return 1
    printf '%s' "$api_resp" | sed -nE "s|.*\\\"${mode}\\\":\\[([0-9.,\\\"]*)\\].*|\\1|p" |
        sed 's|,|\
|g; s|"||g' | sort -n -k1
}

get_episode_url() {
    query_vars="{\"showId\":\"$id\",\"translationType\":\"$mode\",\"episodeString\":\"$ep_no\"}"
    query_ext="{\"persistedQuery\":{\"version\":1,\"sha256Hash\":\"$allanime_query_hash\"}, \"aaReq\":\"$(get_aa_req)\"}"

    if [ -n "$allanime_cookie" ]; then
        api_resp=$(curl -b "$allanime_cookie" -e "$allanime_refr" -sSG -A "$agent" \
            -H "Origin: $allanime_refr" "${allanime_api}/api" \
            --data-urlencode "variables=${query_vars}" --data-urlencode "extensions=${query_ext}")
    else
        api_resp=$(curl -e "$allanime_refr" -sSG -A "$agent" -H "Origin: $allanime_refr" \
            "${allanime_api}/api" --data-urlencode "variables=${query_vars}" --data-urlencode "extensions=${query_ext}")
    fi
    [ -n "$api_resp" ] || die "Episode request failed"
    printf '%s' "$api_resp" | grep -q '"NEED_CAPTCHA"' && die "NEED_CAPTCHA. Solve the captcha on allanime.day and set ALLANIME_COOKIE."
    printf '%s' "$api_resp" | grep -q '"errors"' && die "Episode API error"

    resp=$(process_tobeparsed "$api_resp" | tr '{}' '\
' | sed 's|\\u002F|/|g;s|\\||g' |
        sed -nE 's|.*sourceUrl":"([^"]*)".*sourceName":"([^"]*)".*|\2 :\1|p')
    [ -n "$resp" ] || die "No episode sources found"

    cache_dir=$(mktemp -d) || die "Unable to create temporary directory"
    i=1
    while IFS= read -r source; do
        [ -n "$source" ] || continue
        generate_link_from_source "$source" >"$cache_dir/$i" &
        i=$((i + 1))
    done <<EOF
$resp
EOF
    wait
    links=$(cat "$cache_dir"/* | sort -g -r -s)
    rm -rf "$cache_dir"
    select_quality "$quality"
    [ -n "$episode" ] || die "Episode source not available"
    episode_referer=$(link_referer "$episode")
    episode_player=$(player_json)
    episode_links=$(links_json)
    episode_sources=$(sources_json)
}

# ------------------------------
# QUERY STRING AND ROUTING
# ------------------------------

parse_query() {
    old_ifs=$IFS
    IFS='&'
    set -- $QUERY_STRING
    IFS=$old_ifs
    for param in "$@"; do
        key=${param%%=*}
        value=${param#*=}
        case "$key" in
            query) query=$(printf '%s' "$value" | sed 's/+/ /g') ;;
            show_id) id=$value ;;
            ep_no) ep_no=$value ;;
            quality) quality=$value ;;
            mode)
                case "$value" in
                    sub|dub) mode=$value ;;
                    *) mode=sub ;;
                esac
                ;;
        esac
    done
}

dep_ch curl
dep_ch sed
dep_ch grep
dep_ch base64
dep_ch od
dep_ch dd

if [ -n "$QUERY_STRING" ]; then
    parse_query
    request_uri_path=$(printf '%s' "$REQUEST_URI" | cut -d? -f1)
else
    request_uri_path=$1
    QUERY_STRING=$2
    parse_query
fi

case "$request_uri_path" in
    /search)
        [ -n "$query" ] || die "Missing query parameter"
        result=$(search_anime)
        [ -n "$result" ] || die "No results found"
        printf '%s\n' "$result"
        ;;
    /episodes/*)
        id=$(printf '%s' "$request_uri_path" | cut -d/ -f3)
        [ -n "$id" ] || die "Missing show_id in URL"
        ep_list=$(episodes_list "$id") || die "Episode request failed"
        output=
        first=1
        for ep in $ep_list; do
            [ "$first" -eq 0 ] && output="$output,"
            output="$output$ep"
            first=0
        done
        printf '[%s]\n' "$output"
        ;;
    /episode_url)
        [ -n "$id" ] || die "Missing show_id parameter"
        [ -n "$ep_no" ] || die "Missing ep_no parameter"
        ep_list=$(episodes_list "$id") || die "Episode request failed"
        printf '%s\n' "$ep_list" | grep -Fxq "$ep_no" || die "Episode not released"
        fetch_keys || die "Unable to fetch current AllAnime keys"
        get_episode_url
        if [ -n "$episode_referer" ]; then
            printf '{"episode_url":"%s","player_url":"%s","mode":"%s","headers":{"Referer":"%s"},"player":%s,"links":[%s],"sources":[%s]}\n' \
                "$(json_escape "$episode")" \
                "$(json_escape "$(player_url_value)")" \
                "$(json_escape "$mode")" \
                "$(json_escape "$episode_referer")" \
                "$episode_player" \
                "${episode_links:-}" \
                "${episode_sources:-}"
        else
            printf '{"episode_url":"%s","player_url":"%s","mode":"%s","headers":{},"player":%s,"links":[%s],"sources":[%s]}\n' \
                "$(json_escape "$episode")" \
                "$(json_escape "$(player_url_value)")" \
                "$(json_escape "$mode")" \
                "$episode_player" \
                "${episode_links:-}" \
                "${episode_sources:-}"
        fi
        ;;
    *)
        die "Invalid endpoint"
        ;;
esac
