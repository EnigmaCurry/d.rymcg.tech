#!/bin/bash

## This script parses /tmp/models.txt for 4-tuples (one per line):
##   model_type,model_url,token,cookie
## and then retrieves those models and installs them into the
## appropriate directory for ComfyUI.

while IFS=, read -r model_type model_url token cookie; do
    # Skip empty lines
    if [ -z "${model_type}" ] || [ -z "${model_url}" ]; then
        echo "Skipping invalid line (missing model_type or model_url): ${model_type},${model_url},${token},${cookie}" >&2
        continue
    fi

    basename=$(basename "${model_url}" | cut -d"?" -f1)
    output_path="/ComfyUI/models/${model_type}"
    full_output_path="${output_path}/${basename}"

    # Create target directory if it doesn't exist
    mkdir -p "$(dirname "${full_output_path}")"

    if [ -n "${token}" ]; then
        __hf_cli_succeeded=false
        echo "Downloading ${model_type} from ${model_url} with token."
        if ! wget --header="Authorization: Bearer ${token}" "${model_url}" -O "${full_output_path}"; then
            echo "Failed to download ${model_type} from ${model_url} with token." >&2
            continue
        fi
    elif [ -n "${cookie}" ]; then
        # TODO: complete civitai functionality
        if ! curl -c /tmp/civitai-cookie.txt -d "username=you&password=you" https://civitai.com/login; then
            echo "Failed to establish CivitAI session." >&2
            continue
        fi
        if ! wget --load-cookies /tmp/civitai-cookie.txt \
             --content-disposition \
             "https://civitai.com/api/download/models/<model_id>"; then
            echo "Failed to download ${model_type} from ${model_url} with cookie." >&2
            continue
       fi
    else
        echo "Downloading ${model_type} from ${model_url}."
        if ! wget "${model_url}" -O "${full_output_path}"; then
            echo "Failed to download ${model_type} from ${model_url}." >&2
            continue
        fi
    fi

    echo "Successfully downloaded ${model_type} from ${model_url}."
done < /tmp/models.txt
