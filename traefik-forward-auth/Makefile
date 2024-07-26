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

.PHONY: override-hook
override-hook:
#### This sets the override template variables for docker-compose.instance.yaml:
#### The template dynamically renders to docker-compose.override_{DOCKER_CONTEXT}_{INSTANCE}.yaml
#### These settings are used to automatically generate the service container labels, and traefik config, inside the template.
#### The variable arguments have three forms: `=` `=:` `=@`
####   name=VARIABLE_NAME    # sets the template 'name' field to the value of VARIABLE_NAME found in the .env file
####                         # (this hardcodes the value into docker-compose.override.yaml)
####   name=:VARIABLE_NAME   # sets the template 'name' field to the literal string 'VARIABLE_NAME'
####                         # (this hardcodes the string into docker-compose.override.yaml)
####   name=@VARIABLE_NAME   # sets the template 'name' field to the literal string '${VARIABLE_NAME}'
####                         # (used for regular docker-compose expansion of env vars by name.)
	@${BIN}/docker_compose_override ${ENV_FILE} project=:traefik-forward-auth instance=@TRAEFIK_FORWARD_AUTH_INSTANCE traefik_host=@TRAEFIK_FORWARD_AUTH_HOST http_auth=TRAEFIK_FORWARD_AUTH_HTTP_AUTH http_auth_var=@TRAEFIK_FORWARD_AUTH_HTTP_AUTH ip_sourcerange=@TRAEFIK_FORWARD_AUTH_IP_SOURCERANGE oauth2=TRAEFIK_FORWARD_AUTH_OAUTH2 authorized_group=TRAEFIK_FORWARD_AUTH_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=TRAEFIK_FORWARD_AUTH_MTLS_AUTH mtls_authorized_certs=TRAEFIK_FORWARD_AUTH_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=traefik-forward-auth
