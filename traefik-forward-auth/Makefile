ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_HOST "Enter the traefik-foward-auth host domain name" auth.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_COOKIE_DOMAIN "Enter the cookie domain name (ie ROOT domain)" ${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_GITEA_DOMAIN "Enter your gitea domain name" git.${ROOT_DOMAIN}
	@echo ""
	@echo "Opening Gitea applications page... (login as root)"
	@echo "You should now create a new OAuth2 application: "
	@echo "Set the 'Application Name' the same as AUTH_HOST (or whatever you like)"
	@echo "Set the 'Redirect URL' using https://AUTH_HOST/_oauth, eg. https://auth.${ROOT_DOMAIN}/_oauth"
	@PUBLIC_HTTPS_PORT=$$(${BIN}/dotenv -f ../.env_${DOCKER_CONTEXT} get PUBLIC_HTTPS_PORT); if [[ "$$PUBLIC_HTTPS_PORT" == "443" ]]; then PUBLIC_HTTPS_PORT=""; fi; ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_FORWARD_AUTH_HTTPS_PORT=:$${PUBLIC_HTTPS_PORT}
	@GITEA_DOMAIN=$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_GITEA_DOMAIN); HTTPS_PORT=$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_HTTPS_PORT); xdg-open https://$${GITEA_DOMAIN}$${HTTPS_PORT}/user/settings/applications
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_ID "Copy and Paste the OAuth2 client ID here"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_SECRET "Copy and Paste the OAuth2 client secret here"
	@GITEA_DOMAIN=$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_GITEA_DOMAIN); ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_LOGOUT_REDIRECT "Enter the logout redirect URL" https://$${GITEA_DOMAIN}$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_HTTPS_PORT)/logout
	@GITEA_DOMAIN=$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_GITEA_DOMAIN); HTTPS_PORT=$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_HTTPS_PORT); ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_FORWARD_AUTH_SECRET="$(shell openssl rand -base64 45)" TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_AUTH_URL="https://$${GITEA_DOMAIN}$${HTTPS_PORT}/login/oauth/authorize" TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_TOKEN_URL="https://$${GITEA_DOMAIN}$${HTTPS_PORT}/login/oauth/access_token" TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_USER_URL="https://$${GITEA_DOMAIN}$${HTTPS_PORT}/api/v1/user"

