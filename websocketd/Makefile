ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-no-open
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:

	@${BIN}/reconfigure_ask ${ENV_FILE} WEBSOCKETD_TRAEFIK_HOST "Enter the websocketd domain name" socket${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} WEBSOCKETD_APP_PATH "Enter the websocketd application path" /app
	@${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get WEBSOCKETD_DEV_CONSOLE) == "true" ]] && echo "yes" || echo "no") "Do you want to enable dev console?" "?" && ${BIN}/reconfigure ${ENV_FILE} WEBSOCKETD_DEV_CONSOLE=true || ${BIN}/reconfigure ${ENV_FILE} WEBSOCKETD_DEV_CONSOLE=false
	@${BIN}/reconfigure_auth ${ENV_FILE} WEBSOCKETD

.PHONY: open # Open dev console
open:
	@ENV_FILE=${ENV_FILE} CONTEXT_INSTANCE=${CONTEXT_INSTANCE} ${BIN}/open $$(${BIN}/dotenv -f ${ENV_FILE} get WEBSOCKETD_APP_PATH)

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:websocketd instance=@WEBSOCKETD_INSTANCE traefik_host=@WEBSOCKETD_TRAEFIK_HOST http_auth=WEBSOCKETD_HTTP_AUTH http_auth_var=@WEBSOCKETD_HTTP_AUTH ip_sourcerange=@WEBSOCKETD_IP_SOURCERANGE  oauth2=WEBSOCKETD_OAUTH2 authorized_group=WEBSOCKETD_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=WEBSOCKETD_MTLS_AUTH mtls_authorized_certs=WEBSOCKETD_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=app

.PHONY: install-hook
install-hook:
	@echo
