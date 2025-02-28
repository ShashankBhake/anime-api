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
mode="sub"
quality="best"

die() {
    echo "{\"error\": \"${1}\"}"
    exit 1
}

# ------------------------------
# SCRAPING FUNCTIONS
# ------------------------------

get_links() {
    episode_link="$(curl -e "$allanime_refr" -s "https://${allanime_base}$*" -A "$agent" | sed 's|},{|\
|g' | sed -nE 's|.*link":"([^"]*)".*"resolutionStr":"([^"]*)".*|\2 >\1|p;s|.*hls","url":"([^"]*)".*"hardsub_lang":"en-US".*|\1|p')"

    case "$episode_link" in
    *repackager.wixmp.com*)
        extract_link=$(printf "%s" "$episode_link" | cut -d'>' -f2 | sed 's|repackager.wixmp.com/||g;s|\.urlset.*||g')
        for j in $(printf "%s" "$episode_link" | sed -nE 's|.*/,([^/]*),/mp4.*|\1|p' | sed 's|,|\
|g'); do
            printf "%s >%s\n" "$j" "$extract_link" | sed "s|,[^/]*|${j}|g"
        done | sort -nr
        ;;
    *vipanicdn* | *anifastcdn*)
        if printf "%s" "$episode_link" | head -1 | grep -q "original.m3u"; then
            printf "%s" "$episode_link"
        else
            extract_link=$(printf "%s" "$episode_link" | head -1 | cut -d'>' -f2)
            relative_link=$(printf "%s" "$extract_link" | sed 's|[^/]*$||')
            curl -e "$allanime_refr" -s "$extract_link" -A "$agent" | sed 's|^#.*x||g; s|,.*|p|g; /^#/d; $!N; s|\
| >|' | sed "s|>|>${relative_link}|g" | sort -nr
        fi
        ;;
    *) [ -n "$episode_link" ] && printf "%s\n" "$episode_link" ;;
    esac
}

provider_init() {
    provider_name=$1
    provider_id=$(printf "%s" "$resp" | sed -n "$2" | head -1 | cut -d':' -f2 | sed 's/../&\
/g' | sed 's/^01$/9/g;s/^08$/0/g;s/^05$/=/g;s/^0a$/2/g;s/^0b$/3/g;s/^0c$/4/g;s/^07$/?/g;s/^00$/8/g;s/^5c$/d/g;s/^0f$/7/g;s/^5e$/f/g;s/^17$/\//g;s/^54$/l/g;s/^09$/1/g;s/^48$/p/g;s/^4f$/w/g;s/^0e$/6/g;s/^5b$/c/g;s/^5d$/e/g;s/^0d$/5/g;s/^53$/k/g;s/^1e$/\&/g;s/^5a$/b/g;s/^59$/a/g;s/^4a$/r/g;s/^4c$/t/g;s/^4e$/v/g;s/^57$/o/g;s/^51$/i/g;' | tr -d '\n' | sed "s/\/clock/\/clock\.json/")
}

generate_link() {
    case $1 in
    1) provider_init "wixmp" "/Default :/p" ;;     # wixmp (default)
    2) provider_init "dropbox" "/Sak :/p" ;;       # dropbox
    3) provider_init "wetransfer" "/Kir :/p" ;;    # wetransfer
    4) provider_init "sharepoint" "/S-mp4 :/p" ;;  # sharepoint
    *) provider_init "gogoanime" "/Luf-mp4 :/p" ;; # gogoanime
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
    # Expects: id, ep_no, quality are already set
    episode_embed_gql="query (\$showId: String!, \$translationType: VaildTranslationTypeEnumType!, \$episodeString: String!) { episode( showId: \$showId translationType: \$translationType episodeString: \$episodeString ) { episodeString sourceUrls }}"
    resp=$(curl -e "$allanime_refr" -s -G "${allanime_api}/api" \
        --data-urlencode "variables={\"showId\":\"$id\",\"translationType\":\"$mode\",\"episodeString\":\"$ep_no\"}" \
        --data-urlencode "query=$episode_embed_gql" -A "$agent" | tr '{}' '\n' | sed 's|\\u002F|\/|g;s|\\||g' | sed -nE 's|.*sourceUrl":"--([^"]*)".*sourceName":"([^"]*)".*|\2 :\1|p')
    cache_dir="$(mktemp -d)"
    providers="1 2 3 4 5"
    for provider in $providers; do
        generate_link "$provider" >"$cache_dir/$provider" &
    done
    wait
    links=$(cat "$cache_dir"/* | sed 's|^Mp4-||g;/http/!d;/Alt/d' | sort -g -r -s)
    rm -r "$cache_dir"
    episode=$(select_quality "$quality")
    [ -z "$episode" ] && die "Episode not available"
    echo "$episode"
}

search_anime() {
    # Expects: query variable is set.
    search_gql="query(\$search: SearchInput \$limit: Int \$page: Int \$translationType: VaildTranslationTypeEnumType \$countryOrigin: VaildCountryOriginEnumType) { shows( search: \$search limit: \$limit page: \$page translationType: \$translationType countryOrigin: \$countryOrigin ) { edges { _id name availableEpisodes __typename } }}"
    curl -e "$allanime_refr" -s -G "${allanime_api}/api" \
        --data-urlencode "variables={\"search\":{\"allowAdult\":false,\"allowUnknown\":false,\"query\":\"$query\"},\"limit\":40,\"page\":1,\"translationType\":\"$mode\",\"countryOrigin\":\"ALL\"}" \
        --data-urlencode "query=$search_gql" -A "$agent" | sed 's|Show|\
|g' | sed -nE "s|.*_id\":\"([^\"]*)\",\"name\":\"([^\"]+)\",.*${mode}\":([1-9][^,]*).*|\1\t\2\t\3|p" | sed 's/\\"//g'
}

episodes_list() {
    # Expects: show id as argument ($1)
    episodes_list_gql="query (\$showId: String!) { show( _id: \$showId ) { _id availableEpisodesDetail }}"
    curl -e "$allanime_refr" -s -G "${allanime_api}/api" \
        --data-urlencode "variables={\"showId\":\"$1\"}" \
        --data-urlencode "query=$episodes_list_gql" -A "$agent" | sed -nE "s|.*$mode\":\[([0-9.\",]*)\].*|\1|p" | sed 's|,|\
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
