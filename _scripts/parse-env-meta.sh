#!/usr/bin/env bash
set -eo pipefail

# parse-env-meta.sh ENV_FILE {VAR}
# print the META block from ENV_FILE as validated JSON or as the value for VAR directly.

BIN=$(dirname "${BASH_SOURCE[0]}")
source "${BIN}/funcs.sh"
ENV_FILE="${1:-}"
VAR="${2:-}"
check_var ENV_FILE

# ------------------------------------------------------------------
# Return the first contiguous comment block that starts with "# META:"
# and has no comment line directly above it.
# ------------------------------------------------------------------
parse_meta_block() {
    local file=$1
    [[ -f $file ]] || fault "File not found: $file"

    local prev='' in_block=0 block=''

    while IFS= read -r line || [[ -n $line ]]; do
        if (( in_block == 0 )) && [[ $line =~ ^\#\ META: ]] && ! [[ $prev =~ ^\# ]]; then
            in_block=1
            block+="${line}"$'\n'
        elif (( in_block == 1 )); then
            [[ $line =~ ^\#\  ]] && block+="${line}"$'\n' || break
        fi
        prev=$line
    done <"$file"

    (( in_block )) || fault "No META block found in $file"
    printf '%s' "${block%$'\n'}"
}

# ------------------------------------------------------------------
# Convert all KEY=VALUE lines inside a META block to a JSON object.
# Keys are lower‑cased; ENV_FILE is added as “env_file”.
# The result is validated with jq before being printed.
# ------------------------------------------------------------------
parse_meta_json() {
    local file=$1
    local meta block_line key val json

    meta=$(parse_meta_block "$file")

    # collect key/value pairs
    declare -A map
    while IFS= read -r block_line || [[ -n $block_line ]]; do
        [[ $block_line =~ ^\#\ ([A-Za-z0-9_]+)=(.*) ]] || continue
        key=${BASH_REMATCH[1]}
        val=${BASH_REMATCH[2]}
        key=$(echo "$key" | tr '[:upper:]' '[:lower:]')
        map["$key"]=$val
    done <<<"$meta"

    # add ENV_FILE
    map["env_file"]=$ENV_FILE

    # build JSON string
    json='{'
    first=1
    for key in "${!map[@]}"; do
        (( first )) && first=0 || json+=','
        # escape double quotes and backslashes in values
        esc_val=$(printf '%s' "${map[$key]}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
        json+="\"$key\":\"$esc_val\""
    done
    json+='}'

    # validate JSON
    printf '%s' "$json" | jq . > /dev/null || fault "Generated JSON is invalid"

    printf '%s\n' "$json" | jq
}

# ------------------------------------------------------------------
# Execute: parse ENV_FILE and emit JSON
# ------------------------------------------------------------------
json=$(parse_meta_json "$ENV_FILE")
# If VAR is set, output the corresponding value from the JSON (case‑insensitive)
if [[ -n $VAR ]]; then
    key=$(echo "$VAR" | tr '[:upper:]' '[:lower:]')
    value=$(printf '%s' "$json" | jq -r --arg k "$key" '.[$k] // empty')
    if [[ -n $value ]]; then
        printf '%s\n' "$value"
    else
        fault "No variable named ${VAR^^} in META block - check ${ENV_FILE}"
    fi
else
    # No VAR – just print the whole JSON object
    printf '%s\n' "$json"
fi
