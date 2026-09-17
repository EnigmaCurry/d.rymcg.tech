#!/bin/bash

BIN=${ROOT_DIR}/_scripts
source ${BIN}/funcs.sh

ROOT_DOMAIN=$(get_root_domain)
DOCKER_CONTEXT=$(${BIN}/docker_context)

${BIN}/reconfigure_ask ${ENV_FILE} OAUTH2_PROXY_FORGEJO_DOMAIN "Enter your forgejo domain name" git.${ROOT_DOMAIN}

FORGEJO_DOMAIN=$(${BIN}/dotenv -f ${ENV_FILE} get OAUTH2_PROXY_FORGEJO_DOMAIN)
HTTPS_PORT=$(${BIN}/dotenv -f ${ENV_FILE} get OAUTH2_PROXY_HTTPS_PORT)
AUTH_HOST=$(${BIN}/dotenv -f ${ENV_FILE} get OAUTH2_PROXY_HOST)

## oauth2-proxy uses OIDC discovery: point it at the Forgejo instance root URL and it
## fetches /.well-known/openid-configuration to learn the auth/token/userinfo endpoints.
## Trailing slash is required: Forgejo's discovery doc advertises the issuer WITH a
## trailing slash, and OIDC spec §4.3 requires an exact match.
${BIN}/reconfigure ${ENV_FILE} \
      OAUTH2_PROXY_PROVIDER=oidc \
      OAUTH2_PROXY_OIDC_ISSUER_URL="https://${FORGEJO_DOMAIN}${HTTPS_PORT}/" \
      OAUTH2_PROXY_SCOPE="openid email profile"

echo ""
echo "Opening Forgejo applications page... (login as root)"
echo "https://${FORGEJO_DOMAIN}${HTTPS_PORT}/user/settings/applications"
echo "You should now create a new OAuth2 application:"
echo "  Application Name: ${AUTH_HOST}  (or whatever you like)"
echo "  Redirect URI:     https://${AUTH_HOST}${HTTPS_PORT}/oauth2/callback"
echo "  Confidential:     yes"

xdg-open https://${FORGEJO_DOMAIN}${HTTPS_PORT}/user/settings/applications 2>/dev/null || true

${BIN}/reconfigure_ask ${ENV_FILE} OAUTH2_PROXY_CLIENT_ID "Copy and paste the OAuth2 client ID here"
${BIN}/reconfigure_ask ${ENV_FILE} OAUTH2_PROXY_CLIENT_SECRET "Copy and paste the OAuth2 client secret here"
