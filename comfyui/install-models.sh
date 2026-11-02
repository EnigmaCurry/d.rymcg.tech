#!/bin/bash

## This script parses /tmp/models.txt for 3-tuples (one per line):
##   model_type,model_url,token
## and then retrieves those models and installs them into the
## appropriate directory for ComfyUI.

## Append a query parameter to a URL, using `?` or `&` as appropriate.
add_query_param() {
    local url="$1" param="$2"
    if [[ "${url}" == *"?"* ]]; then
        echo "${url}&${param}"
    else
        echo "${url}?${param}"
    fi
}

## Return 0 if the file looks like an HTML document rather than a model.
is_html_file() {
    head -c 1024 "$1" | grep -qiE '^\s*(<!doctype html|<html)'
}

while IFS=, read -r model_type model_url token; do
    # Skip empty lines
    if [ -z "${model_type}" ] || [ -z "${model_url}" ]; then
        echo "Skipping invalid line (missing model_type or model_url): ${model_type},${model_url},${token}" >&2
        continue
    fi

    # Hugging Face /blob/ URLs serve the web viewer page, not the file.
    # The raw file lives at the same path under /resolve/.
    if [[ "${model_url}" =~ ^https://huggingface\.co/.*/blob/.* ]]; then
        model_url="${model_url/\/blob\//\/resolve\/}"
        echo "Rewrote Hugging Face blob URL to: ${model_url}"
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
            if ! wget "$(add_query_param "${model_url}" "token=${token}")" -O "${full_output_path}"; then
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
            if ! wget "$(add_query_param "${model_url}" "token=${token}")" -O "${full_output_path}"; then
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

    # A web page where a model should be means the URL pointed at a viewer
    # page, or the service answered with a login/error page instead of the
    # file. Don't leave it behind masquerading as a model.
    if is_html_file "${full_output_path}"; then
        echo "Failed to download ${model_type} from ${model_url}: the server returned an HTML page, not a model file. Check that the URL points directly at the file, and that your token is valid." >&2
        rm -f "${full_output_path}"
        continue
    fi

    echo "Successfully downloaded ${model_type} from ${model_url}."
done < /tmp/models.txt
