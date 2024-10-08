#!/bin/bash

BIN=${ROOT_DIR}/_scripts
source ${BIN}/funcs.sh

ROOT_DOMAIN=$(get_root_domain)
DOCKER_CONTEXT=$(${BIN}/docker_context)

${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_FORGEJO_DOMAIN "Enter your forgejo domain name" git.${ROOT_DOMAIN}

FORGEJO_DOMAIN=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_FORGEJO_DOMAIN)
HTTPS_PORT=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_HTTPS_PORT)

${BIN}/reconfigure ${ENV_FILE} \
      TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_AUTH_URL="https://${FORGEJO_DOMAIN}${HTTPS_PORT}/login/oauth/authorize" \
      TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_TOKEN_URL="https://${FORGEJO_DOMAIN}${HTTPS_PORT}/login/oauth/access_token" \
      TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_USER_URL="https://${FORGEJO_DOMAIN}${HTTPS_PORT}/api/v1/user"

echo ""
echo "Opening Forgejo applications page... (login as root)"
echo "https://${FORGEJO_DOMAIN}${HTTPS_PORT}/user/settings/applications"
echo "You should now create a new OAuth2 application: "
echo "Set the 'Application Name' the same as AUTH_HOST (or whatever you like)"
echo "Set the 'Redirect URL' using https://AUTH_HOST/_oauth, eg. https://auth.${ROOT_DOMAIN}/_oauth"

xdg-open https://${FORGEJO_DOMAIN}${HTTPS_PORT}/user/settings/applications

${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_ID "Copy and Paste the OAuth2 client ID here"

${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_SECRET "Copy and Paste the OAuth2 client secret here"
${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_LOGOUT_REDIRECT "Enter the logout redirect URL" https://${FORGEJO_DOMAIN}$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_HTTPS_PORT)/logout

${BIN}/reconfigure ${ENV_FILE} TRAEFIK_FORWARD_AUTH_DEFAULT_PROVIDER=generic-oauth
