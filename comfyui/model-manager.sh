#!/bin/bash

## This script prompts user for information about models they want to
## install into ComfyUI: model type, URL to download model from, token
## (optional, for some models downloaded from services like Hugging
## Face, CivitAI, etc.); saves the info to a text file; copies the
## text file to the ComfyUI Docker container; and runs a script in the
## container to install them.
##
## The following should be set prior to calling this script.
## BIN
## ENV_FILE
## COMFYUI_HUGGING_FACE_TOKEN
## COMFYUI_CIVITAI_TOKEN
##
## This script must reside in `/path/to/d.rymcg.text/comfyui/`

# Configuration
BIN="${BIN:-../_scripts}"
: "${ENV_FILE:?ENV_FILE is not set}"
TEMP_FILE=$(mktemp)
trap 'rm -f "${TEMP_FILE}"' EXIT

# Get container name
CONTAINER_NAME=$("${BIN}/dotenv" -f "${ENV_FILE}" get DOCKER_COMPOSE_PROFILES)
if [ -z "${CONTAINER_NAME}" ]; then
    echo "Error: DOCKER_COMPOSE_PROFILES not found in ${ENV_FILE}"
    exit 1
fi
CONTAINER_NAME="comfyui-comfyui-${CONTAINER_NAME}-1"

cat <<'EOF'

Install Models into ComfyUI
===========================

You will be asked for information for each model you want to install:
 - Model Type (e.g., checkpoint, vae, diffusion_model)
 - Model URL (the URL to download the model)
 - Token (your token from your Huggingface/CivitAI/etc. account)

Token is optional: it may be required to download certain models from
Hugging Face, CivitAI, or other services that use a token to allow
downloading certain models.

EOF

# Model types
choices="audio_encoders checkpoints clip clip_vision configs controlnet diffusers diffusion_models embeddings gligen hypernetworks loras model_patches photomaker style_models text_encoders unet upscale_models vae vae_approx"

# Loop to collect multiple models
while true; do
    echo ""
    model_type=$("${BIN}/script-wizard" choose "What type of model are you installing?" ${choices} --default "checkpoints")
    echo ""
    model_url=$("${BIN}/ask_echo" "What is the download URL of the model?" "")
    echo ""
    if [[ "${model_url}" =~ .*civitai\.com.* ]]; then
        token=$("${BIN}/ask_echo_blank" "Enter authentication token (or leave blank):" "" $(${BIN}/dotenv -f ${ENV_FILE} get COMFYUI_CIVITAI_TOKEN))
    elif [[ "${model_url}" =~ .*huggingface\.co.* ]]; then
        token=$("${BIN}/ask_echo_blank" "Enter authentication token (or leave blank):" "" $(${BIN}/dotenv -f ${ENV_FILE} get COMFYUI_HUGGING_FACE_TOKEN))
    else
        token=$("${BIN}/ask_echo_blank" "Enter authentication token (or leave blank):" "")
    fi

    # Write to temp file as comma-separated tuple
    echo "${model_type},${model_url},${token}" >> "${TEMP_FILE}"

    echo ""
    if [ "$("${BIN}/script-wizard" choose "Add another model?" "Yes" "No")" = "No" ]; then
        break
    fi
done

# Display models to be installed
echo ""
echo "The following models will be installed:"
echo "======================================="
while IFS=',' read -r type url token; do
    echo -e "Model Type:\t${type}"
    echo -e "Model URL:\t${url}"
    [ -n "${token}" ] && echo -e "Token:\t\t[REDACTED]" || echo -e "Token:\t\tNone"
    echo "---"
done < "${TEMP_FILE}"

# Confirm installation
echo ""
if [ "$("${BIN}/script-wizard" choose "Confirm installation?" "Yes" "No")" = "No" ]; then
    echo -e "\nInstallation cancelled.\n"
    exit 0
fi

echo ""
# Copy temp models-to-install file to container
docker cp "${TEMP_FILE}" "${CONTAINER_NAME}:/tmp/models.txt"

# Execute script in container to install models
docker exec -it "${CONTAINER_NAME}" /install-models.sh

echo -e "\nModel installation process complete.\n"
