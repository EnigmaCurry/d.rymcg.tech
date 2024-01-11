ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_HOST "Enter the traefik-foward-auth host domain name" auth.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_FORWARD_AUTH_COOKIE_DOMAIN "Enter the cookie domain name (ie ROOT domain)" ${ROOT_DOMAIN}
	@${BIN}/reconfigure_password ${ENV_FILE} TRAEFIK_FORWARD_AUTH_SECRET 45
	@echo
	@ENV_FILE=${ENV_FILE} ROOT_DIR=${ROOT_DIR} bash ./configure_https_port.sh || true

	@echo
	@${BIN}/reconfigure_choose ${ENV_FILE} TRAEFIK_FORWARD_AUTH_SELECTED_PROVIDER "Select the OAuth provider to use" "gitea" "github" "google" "discord"
	@test "gitea" == $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_SELECTED_PROVIDER) && ENV_FILE=${ENV_FILE} ROOT_DIR=${ROOT_DIR} bash ./configure_gitea.sh || true
	@test "github" == $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_SELECTED_PROVIDER) && ENV_FILE=${ENV_FILE} ROOT_DIR=${ROOT_DIR} bash ./configure_github.sh || true
	@test "google" == $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_SELECTED_PROVIDER) && ENV_FILE=${ENV_FILE} ROOT_DIR=${ROOT_DIR} bash ./configure_google.sh || true
	@test "discord" == $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_FORWARD_AUTH_SELECTED_PROVIDER) && ENV_FILE=${ENV_FILE} ROOT_DIR=${ROOT_DIR} bash ./configure_discord.sh || true


.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=traefik-forward-auth
