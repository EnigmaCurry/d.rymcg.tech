ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_HOST "Enter the auth host domain name" auth.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_COOKIE_DOMAIN "Enter the cookie domain name" ${ROOT_DOMAIN}
	@echo ""
	@echo "Opening Gitea applications page... (login as root)"
	@echo "You should now create a new OAuth2 application: "
	@echo "Set the 'Application Name' the same as AUTH_HOST (or whatever you like)"
	@echo "Set the 'Redirect URL' using https://AUTH_HOST/_oauth, eg. https://auth.${ROOT_DOMAIN}/_oauth"
	@${BIN}/reconfigure ${ENV_FILE} TRAEFIK_FORWARD_AUTH_HTTPS_PORT=$$(${BIN}/dotenv -f ../.env_${DOCKER_CONTEXT} get PUBLIC_HTTPS_PORT)
	@HTTPS_PORT=$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_HTTPS_PORT); xdg-open https://git.${ROOT_DOMAIN}:$${HTTPS_PORT}/user/settings/applications
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_ID "Copy and Paste the OAuth2 client ID here"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_SECRET "Copy and Paste the OAuth2 client secret here"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_LOGOUT_REDIRECT "Enter the logout redirect URL" https://git.${ROOT_DOMAIN}:$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_HTTPS_PORT)/logout
	@HTTPS_PORT=$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_HTTPS_PORT); if [[ "$$HTTPS_PORT" == "443" ]]; then HTTPS_PORT=""; else HTTPS_PORT=":$${HTTPS_PORT}"; fi; ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_FORWARD_AUTH_SECRET="$(shell openssl rand -base64 45)" TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_AUTH_URL="https://git.${ROOT_DOMAIN}$${HTTPS_PORT}/login/oauth/authorize" TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_TOKEN_URL="https://git.${ROOT_DOMAIN}$${HTTPS_PORT}/login/oauth/access_token" TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_USER_URL="https://git.${ROOT_DOMAIN}$${HTTPS_PORT}/api/v1/user"

