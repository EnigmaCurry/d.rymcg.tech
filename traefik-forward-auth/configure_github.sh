#!/bin/bash

BIN=${ROOT_DIR}/_scripts
source ${BIN}/funcs.sh

ROOT_DOMAIN=$(get_root_domain)
DOCKER_CONTEXT=$(${BIN}/docker_context)

${BIN}/reconfigure ${ENV_FILE} \
      TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_AUTH_URL="https://github.com/login/oauth/authorize" \
      TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_TOKEN_URL="https://github.com/login/oauth/access_token" \
      TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_USER_URL="https://api.github.com/user"

echo ""
echo "Opening the GitHub applications page... "
echo "https://github.com/settings/applications/new"
echo ""
echo "Create a new OAuth2 app:"
echo " * Set the 'Application Name' the same as AUTH_HOST (or whatever you like)"
echo " * Set the 'Homepage URL' the same as https://AUTH_HOST (or whatever you like)"
echo " * Set the 'Authorization Callback URL' using https://AUTH_HOST/_oauth, eg. https://auth.${ROOT_DOMAIN}/_oauth"
echo ""
echo " * Click 'Register the application'"
echo " * Click 'Generate a new client secret'."
echo ""

xdg-open https://github.com/settings/applications/new

${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_ID "Copy and Paste the OAuth2 client ID here (make sure theres no spaces in it)"

${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_SECRET "Copy and Paste the OAuth2 client secret here"


${BIN}/reconfigure ${ENV_FILE} TRAEFIK_FORWARD_AUTH_DEFAULT_PROVIDER=generic-oauth
