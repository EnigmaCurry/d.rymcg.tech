#!/bin/bash

## This script parses /tmp/models.txt for 3-tuples (one per line):
##   model_type,model_url,token
## and then retrieves those models and installs them into the
## appropriate directory for ComfyUI.

while IFS=, read -r model_type model_url token; do
    # Skip empty lines
    if [ -z "${model_type}" ] || [ -z "${model_url}" ]; then
        echo "Skipping invalid line (missing model_type or model_url): ${model_type},${model_url},${token}" >&2
        continue
    fi

    basename=$(basename "${model_url}" | cut -d"?" -f1)
    output_path="/ComfyUI/models/${model_type}"
    full_output_path="${output_path}/${basename}"

    # Create target directory if it doesn't exist
    mkdir -p "$(dirname "${full_output_path}")"

    echo "Downloading ${model_type} from ${model_url}"
    if [ -n "${token}" ]; then
        echo "with token"

        # Check domain and handle accordingly
        if [[ "${model_url}" =~ .*civitai\.com.* ]]; then
            # For CivitAI: append token as query parameter
            if ! wget "${model_url}&token+${token}" -O "${full_output_path}"; then
                echo "Failed to download ${model_type} from CivitAI (${model_url}) with token." >&2
                continue
            fi
        elif [[ "${model_url}" =~ .*huggingface\.co.* ]]; then
            # For Hugging Face: use Authorization header with Bearer token
            if ! wget --header="Authorization: Bearer ${token}" "${model_url}" -O "${full_output_path}"; then
                echo "Failed to download ${model_type} from Hugging Face (${model_url}) with token." >&2
                continue
            fi
        else
            # Default case: append token as query parameter
            if ! wget "${model_url}&token=${token}" -O "${full_output_path}"; then
                echo "Failed to download ${model_type} from ${model_url} with token." >&2
                continue
            fi
        fi
    else
        if ! wget "${model_url}" -O "${full_output_path}"; then
            echo "Failed to download ${model_type} from ${model_url}." >&2
            continue
        fi
    fi

    echo "Successfully downloaded ${model_type} from ${model_url}."
done < /tmp/models.txt
