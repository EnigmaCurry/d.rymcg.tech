#!/bin/bash

BIN=${ROOT_DIR}/_scripts
source ${BIN}/funcs.sh

ROOT_DOMAIN=$(get_root_domain)
DOCKER_CONTEXT=$(${BIN}/docker_context)

${BIN}/reconfigure ${ENV_FILE} \
      TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_AUTH_URL="https://discord.com/api/oauth2/authorize" \
      TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_TOKEN_URL="https://discord.com/api/oauth2/token" \
      TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_USER_URL="https://discord.com/api/users/@me" \
      TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_SCOPE="identify email"

echo "## Create a new Discord app in your browser ..."

xdg-open https://discord.com/developers/applications

${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_ID "Copy and Paste the OAuth2 client ID here (make sure theres no spaces in it)"

${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_SECRET "Copy and Paste the OAuth2 client secret here"

${BIN}/reconfigure ${ENV_FILE} TRAEFIK_FORWARD_AUTH_DEFAULT_PROVIDER=generic-oauth
