ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook # Configure whoami .env file
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} AUTH_HOST "Enter the auth host domain name" auth.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} COOKIE_DOMAIN "Enter the cookie domain name" ${ROOT_DOMAIN}
	@echo ""
	@echo "Opening Gitea applications page... (login as root)"
	@echo "You should now create a new OAuth2 application: "
	@echo "Set the 'Application Name' the same as AUTH_HOST (or whatever you like)"
	@echo "Set the 'Redirect URL' using https://AUTH_HOST/_oauth, eg. https://auth.${ROOT_DOMAIN}/_oauth"
	xdg-open https://git.${ROOT_DOMAIN}/user/settings/applications
	@${BIN}/reconfigure_ask ${ENV_FILE} PROVIDERS_GENERIC_OAUTH_CLIENT_ID "Copy and Paste the OAuth2 client ID here"
	@${BIN}/reconfigure_ask ${ENV_FILE} PROVIDERS_GENERIC_OAUTH_CLIENT_SECRET "Copy and Paste the OAuth2 client secret here"
	@echo "ok"
	@${BIN}/reconfigure ${ENV_FILE} SECRET="$(shell openssl rand -base64 45)" PROVIDERS_GENERIC_OAUTH_AUTH_URL="https://git.${ROOT_DOMAIN}/login/oauth/authorize" PROVIDERS_GENERIC_OAUTH_TOKEN_URL="https://git.${ROOT_DOMAIN}/login/oauth/access_token" PROVIDERS_GENERIC_OAUTH_USER_URL="https://git.${ROOT_DOMAIN}/api/v1/user"

