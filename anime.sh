#!/bin/sh
# Simple API to search anime, list episodes, and get playback URL.
# Remove all interactive UI and player functions from the original script.
# Usage (as CGI or via command-line):
#   /search?query=your+anime+query
#   /episodes/<show_id>
#   /episode_url?show_id=<show_id>&ep_no=<episode_number>&quality=best

# Configuration
agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0"
allanime_refr="https://allmanga.to"
allanime_base="allanime.day"
allanime_api="https://api.${allanime_base}"
allanime_key="$(printf '%s' 'SimtVuagFbGR2K7P' | openssl dgst -sha256 -binary | od -A n -t x1 | tr -d ' \n')"
mode="sub"  # Default mode, can be overridden by query parameter
quality="best"
LC_ALL=C
export LC_ALL

die() {
    echo "{\"error\": \"${1}\"}"
    exit 1
}

# ------------------------------
# SCRAPING FUNCTIONS
# ------------------------------

get_links() {
    response="$(curl -e "$allanime_refr" -s "https://${allanime_base}$*" -A "$agent")"
    episode_link="$(printf '%s' "$response" | sed 's|},{|\
|g' | sed -nE 's|.*link":"([^"]*)".*"resolutionStr":"([^"]*)".*|\2 >\1|p;s|.*hls","url":"([^"]*)".*"hardsub_lang":"en-US".*|\1|p')"

    case "$episode_link" in
    *repackager.wixmp.com*)
        extract_link=$(printf "%s" "$episode_link" | cut -d'>' -f2 | sed 's|repackager.wixmp.com/||g;s|\.urlset.*||g')
        for j in $(printf "%s" "$episode_link" | sed -nE 's|.*/,([^/]*),/mp4.*|\1|p' | sed 's|,|\
|g'); do
            printf "%s >%s\n" "$j" "$extract_link" | sed "s|,[^/]*|${j}|g"
        done | sort -nr
        ;;
    *master.m3u8*)
        m3u8_refr=$(printf '%s' "$response" | sed -nE 's|.*Referer":"([^"]*)".*|\1|p')
        [ -n "$m3u8_refr" ] && printf '%s\n' "m3u8_refr >$m3u8_refr"
        extract_link=$(printf "%s" "$episode_link" | head -1 | cut -d'>' -f2)
        relative_link=$(printf "%s" "$extract_link" | sed 's|[^/]*$||')
        m3u8_streams="$(curl -e "$m3u8_refr" -s "$extract_link" -A "$agent")"
        if printf "%s" "$m3u8_streams" | grep -q "EXTM3U"; then
            printf "%s" "$m3u8_streams" | sed 's|^#EXT-X-STREAM.*x||g; s|,.*|p|g; /^#/d; $!N; s|\n| >|;/EXT-X-I-FRAME/d' |
                sed "s|>|cc>${relative_link}|g" | sort -nr
        fi
        printf '%s' "$response" | sed -nE 's|.*"subtitles":\[\{"lang":"en","label":"English","default":"default","src":"([^"]*)".*|subtitle >\1|p'
        ;;
    *) [ -n "$episode_link" ] && printf "%s\n" "$episode_link" ;;
    esac

    printf "%s" "$*" | grep -q "tools.fast4speed.rsvp" && printf "%s\n" "Yt >$*"
}

provider_init() {
    provider_name=$1
    provider_id=$(printf "%s" "$resp" | sed -n "$2" | head -1 | cut -d':' -f2 | sed 's/../&\
/g' | sed 's/^79$/A/g;s/^7a$/B/g;s/^7b$/C/g;s/^7c$/D/g;s/^7d$/E/g;s/^7e$/F/g;s/^7f$/G/g;s/^70$/H/g;s/^71$/I/g;s/^72$/J/g;s/^73$/K/g;s/^74$/L/g;s/^75$/M/g;s/^76$/N/g;s/^77$/O/g;s/^68$/P/g;s/^69$/Q/g;s/^6a$/R/g;s/^6b$/S/g;s/^6c$/T/g;s/^6d$/U/g;s/^6e$/V/g;s/^6f$/W/g;s/^60$/X/g;s/^61$/Y/g;s/^62$/Z/g;s/^59$/a/g;s/^5a$/b/g;s/^5b$/c/g;s/^5c$/d/g;s/^5d$/e/g;s/^5e$/f/g;s/^5f$/g/g;s/^50$/h/g;s/^51$/i/g;s/^52$/j/g;s/^53$/k/g;s/^54$/l/g;s/^55$/m/g;s/^56$/n/g;s/^57$/o/g;s/^48$/p/g;s/^49$/q/g;s/^4a$/r/g;s/^4b$/s/g;s/^4c$/t/g;s/^4d$/u/g;s/^4e$/v/g;s/^4f$/w/g;s/^40$/x/g;s/^41$/y/g;s/^42$/z/g;s/^08$/0/g;s/^09$/1/g;s/^0a$/2/g;s/^0b$/3/g;s/^0c$/4/g;s/^0d$/5/g;s/^0e$/6/g;s/^0f$/7/g;s/^00$/8/g;s/^01$/9/g;s/^15$/-/g;s/^16$/./g;s/^67$/_/g;s/^46$/~/g;s/^02$/:/g;s/^17$/\//g;s/^07$/?/g;s/^1b$/#/g;s/^63$/\[/g;s/^65$/\]/g;s/^78$/@/g;s/^19$/!/g;s/^1c$/$/g;s/^1e$/\&/g;s/^10$/\(/g;s/^11$/\)/g;s/^12$/*/g;s/^13$/+/g;s/^14$/,/g;s/^03$/;/g;s/^05$/=/g;s/^1d$/%/g' | tr -d '\n' | sed "s/\/clock/\/clock\.json/")
}

generate_link() {
    case $1 in
    1) provider_init "wixmp" "/Default :/p" ;;
    2) provider_init "youtube" "/Yt-mp4 :/p" ;;
    3) provider_init "sharepoint" "/S-mp4 :/p" ;;
    *) provider_init "hianime" "/Luf-Mp4 :/p" ;;
    esac
    [ -n "$provider_id" ] && get_links "$provider_id"
}

select_quality() {
    case "$1" in
    best) result=$(printf "%s" "$links" | head -n1) ;;
    worst) result=$(printf "%s" "$links" | grep -E '^[0-9]{3,4}' | tail -n1) ;;
    *) result=$(printf "%s" "$links" | grep -m 1 "$1") ;;
    esac
    [ -z "$result" ] && result=$(printf "%s" "$links" | head -n1)
    # Return only the URL part (after the > delimiter)
    printf "%s" "$result" | cut -d'>' -f2
}

get_episode_url() {
    # Expects: id, ep_no, quality, mode are already set
    # mode determines whether to fetch sub or dub version
    episode_embed_gql="query (\$showId: String!, \$translationType: VaildTranslationTypeEnumType!, \$episodeString: String!) { episode( showId: \$showId translationType: \$translationType episodeString: \$episodeString ) { episodeString sourceUrls }}"
    api_resp=$(curl -e "$allanime_refr" -s -H "Content-Type: application/json" -X POST "${allanime_api}/api" \
        --data "{\"variables\":{\"showId\":\"$id\",\"translationType\":\"$mode\",\"episodeString\":\"$ep_no\"},\"query\":\"$episode_embed_gql\"}" -A "$agent")

    if printf "%s" "$api_resp" | grep -q '"tobeparsed"'; then
        blob="$(printf "%s" "$api_resp" | sed -nE 's|.*"tobeparsed":"([^"]*)".*|\1|p')"
        tmp="$(mktemp)"
        printf '%s' "$blob" | base64 -d >"$tmp"
        iv="$(dd if="$tmp" bs=1 count=12 2>/dev/null | od -A n -t x1 | tr -d ' \n')"
        ctr="${iv}00000002"
        plain="$(dd if="$tmp" bs=1 skip=12 2>/dev/null | openssl enc -d -aes-256-ctr -K "$allanime_key" -iv "$ctr" -nosalt -nopad 2>/dev/null)"
        rm -f "$tmp"
        resp="$(LC_ALL=C printf '%s' "$plain" | LC_ALL=C tr '{}' '\n' | sed -nE 's|.*"sourceUrl":"--([^"]*)".*"sourceName":"([^"]*)".*|\2 :\1|p')"
    else
        resp="$(LC_ALL=C printf "%s" "$api_resp" | LC_ALL=C tr '{}' '\n' | sed 's|\\u002F|\/|g;s|\\||g' | sed -nE 's|.*sourceUrl":"--([^"]*)".*sourceName":"([^"]*)".*|\2 :\1|p')"
    fi

    cache_dir="$(mktemp -d)"
    providers="1 2 3 4"
    for provider in $providers; do
        generate_link "$provider" >"$cache_dir/$provider" &
    done
    wait
    links=$(cat "$cache_dir"/* | sort -g -r -s)
    rm -r "$cache_dir"
    episode=$(select_quality "$quality")
    [ -z "$episode" ] && die "Episode not available"
    echo "$episode"
}

search_anime() {
    # Expects: query variable is set.
    # Returns: id, title, sub_episodes, dub_episodes (tab separated)
    search_gql="query(\$search: SearchInput \$limit: Int \$page: Int \$countryOrigin: VaildCountryOriginEnumType) { shows( search: \$search limit: \$limit page: \$page countryOrigin: \$countryOrigin ) { edges { _id name availableEpisodes __typename } }}"
    curl -e "$allanime_refr" -s -H "Content-Type: application/json" -X POST "${allanime_api}/api" \
        --data "{\"variables\":{\"search\":{\"allowAdult\":false,\"allowUnknown\":false,\"query\":\"$query\"},\"limit\":40,\"page\":1,\"countryOrigin\":\"ALL\"},\"query\":\"$search_gql\"}" -A "$agent" | sed 's|Show|\
|g' | sed -nE 's|.*_id":"([^"]*)","name":"([^"]+)".*"sub":([0-9]+).*"dub":([0-9]+).*|\1\t\2\t\3\t\4|p; s|.*_id":"([^"]*)","name":"([^"]+)".*"sub":([0-9]+).*"dub":null.*|\1\t\2\t\3\t0|p; s|.*_id":"([^"]*)","name":"([^"]+)".*"sub":null.*"dub":([0-9]+).*|\1\t\2\t0\t\3|p' | sed 's/\\"//g'
}

episodes_list() {
    # Expects: show id as argument ($1), mode variable is set (sub/dub)
    # Returns episode numbers based on current mode (sub or dub)
    episodes_list_gql="query (\$showId: String!) { show( _id: \$showId ) { _id availableEpisodesDetail }}"
    curl -e "$allanime_refr" -s -H "Content-Type: application/json" -X POST "${allanime_api}/api" \
        --data "{\"variables\":{\"showId\":\"$1\"},\"query\":\"$episodes_list_gql\"}" -A "$agent" | sed -nE "s|.*$mode\":\[([0-9.\",]*)\].*|\1|p" | sed 's|,|\
|g; s|"||g' | sort -n -k 1
}

# ------------------------------
# QUERY STRING PARSING (basic)
# ------------------------------
parse_query() {
    # Parse key=value pairs from QUERY_STRING, splitting only on "&" so that spaces are preserved.
    old_IFS="$IFS"
    IFS='&'
    set -- $QUERY_STRING
    IFS="$old_IFS"
    for param in "$@"; do
        key=${param%%=*}
        value=${param#*=}
        case "$key" in
            query) query=$(echo "$value" | sed 's/+/ /g') ;;
            show_id) id="$value" ;;
            ep_no) ep_no="$value" ;;
            quality) quality="$value" ;;
            raw) raw="$value" ;;
            mode) 
                # Validate mode is either sub or dub
                case "$value" in
                    sub|dub) mode="$value" ;;
                    *) mode="sub" ;;  # Default to sub if invalid
                esac
                ;;
        esac
    done
}

# ------------------------------
# MAIN API ROUTING
# ------------------------------

# Determine request URI (if running as CGI, QUERY_STRING is provided)
if [ -n "$QUERY_STRING" ]; then
    parse_query
    REQUEST_URI_PATH=$(echo "$REQUEST_URI" | cut -d'?' -f1)
else
    # Otherwise, assume the first argument is the endpoint and the second (optional) is the query string.
    REQUEST_URI_PATH="$1"
    QUERY_STRING="$2"
    parse_query
fi

case "$REQUEST_URI_PATH" in
/search)
    [ -z "$query" ] && die "Missing query parameter"
    result=$(search_anime)
    # Write the result into a temporary file
    tempfile=$(mktemp /tmp/ani_api.XXXXXX)
    echo "$result" >"$tempfile"
    # Convert tab-separated output (id, title, episodes) into a JSON array.
    # output="["
    # first=1
    # while IFS=$'\t' read -r anime_id title eps; do
    #     if [ $first -eq 0 ]; then
    #         output="${output},"
    #     fi
    #     output="${output}{\"id\":\"${anime_id}\",\"title\":\"${title}\",\"episodes\":${eps}}"
    #     first=0
    # done <"$tempfile"
    # rm "$tempfile"
    # output="${output}]"
    output="$result"
    echo "$output"
    ;;
/episodes/*)
    # Endpoint like /episodes/<show_id>
    show_id=$(echo "$REQUEST_URI_PATH" | cut -d'/' -f3)
    [ -z "$show_id" ] && die "Missing show_id in URL"
    ep_list=$(episodes_list "$show_id")
    # Build a JSON array of episode numbers
    output="["
    first=1
    for ep in $ep_list; do
        [ $first -eq 0 ] && output="${output},"
        output="${output}${ep}"
        first=0
    done
    output="${output}]"
    echo "$output"
    ;;
/episode_url)
    [ -z "$id" ] && die "Missing show_id parameter"
    [ -z "$ep_no" ] && die "Missing ep_no parameter"
    quality=${quality:-best}
    # Check if the episode is available using the episodes_list
    available=$(episodes_list "$id" | grep -w "$ep_no")
    [ -z "$available" ] && die "Episode not released"
    url=$(get_episode_url)
    echo "{\"episode_url\": \"${url}\"}"
    ;;
*)
    echo "{\"error\": \"Invalid endpoint\"}"
    exit 1
    ;;
esac
