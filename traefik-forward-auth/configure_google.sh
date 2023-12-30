#!/bin/bash

BIN=${ROOT_DIR}/_scripts
source ${BIN}/funcs.sh

ROOT_DOMAIN=$(get_root_domain)
DOCKER_CONTEXT=$(${BIN}/docker_context)

echo ""
echo "Opening the Google applications page... "
echo "https://console.developers.google.com/"
echo " * You should now create a new google cloud project."
echo " * Enter a project name that relates to this instance."
echo " * Select the project for editing."
echo ""
echo " * In the menu under API and Services, click OAuth consent screen."
echo " * Click 'Configure Consent Screen.'"
echo " * Choose the User Type of 'External' for the Oauth screen."
echo " * Enter all the details:"
echo "   * Enter the Application homepage: https://${ROOT_DOMAIN}"
echo "   * Add an authorized root domain part only, eg. example.com"
echo " * Save and Continue."
echo " * Click 'Add or Remove Scopes'."
echo "   * Select .../auth/userinfo.email to receive the user's email addresses."
echo " * Save and Continue."
echo " * Skip adding any test users."
echo " * Click Back to Dashboard. "
echo " * Click 'Publish App'."
echo ""
echo " * In the menu under API and Services, click Credentials."
echo " * Click 'Create Credentials'."
echo " * Choose 'OAuth client ID'."
echo " * Choose 'Web application' type."
echo " * Enter the client name: ${ROOT_DOMAIN}"
echo " * Skip entering Javascript origins."
echo " * Enter the Authorized Redirect URI: https://auth.${ROOT_DOMAIN}/_oauth"
echo " * Click Create."
echo " * Copy the Client ID and Client Secret shown."
echo ""

xdg-open https://console.developers.google.com/

${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_PROVIDERS_GOOGLE_CLIENT_ID "Copy and Paste the OAuth2 client ID here"

${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_PROVIDERS_GOOGLE_CLIENT_SECRET "Copy and Paste the OAuth2 client secret here"

${BIN}/reconfigure ${ENV_FILE} TRAEFIK_FORWARD_AUTH_DEFAULT_PROVIDER=google
