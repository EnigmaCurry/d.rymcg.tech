ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} PAIRDROP_TRAEFIK_HOST "Enter the pairdrop domain name" pairdrop${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} PAIRDROP_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} PAIRDROP
	@${BIN}/reconfigure_ask ${ENV_FILE} PAIRDROP_TURN_DOMAIN "Enter the TURN server domain"
	@${BIN}/reconfigure_ask ${ENV_FILE} PAIRDROP_TURN_LISTEN_PORT "Enter the TURN port number"
	@${BIN}/reconfigure_ask ${ENV_FILE} PAIRDROP_TURN_TLS_PORT "Enter the TURN TLS port number"
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} PAIRDROP_TURN_USERNAME "Enter the TURN username (optional)"
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} PAIRDROP_TURN_PASSWORD "Enter the TURN password (optional)"
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} PAIRDROP_COTURN_STATIC_AUTH_SECRET "Enter the static auth secret token from coturn (optional)"

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:pairdrop instance=@PAIRDROP_INSTANCE traefik_host=@PAIRDROP_TRAEFIK_HOST http_auth=PAIRDROP_HTTP_AUTH http_auth_var=@PAIRDROP_HTTP_AUTH ip_sourcerange=@PAIRDROP_IP_SOURCERANGE oauth2=PAIRDROP_OAUTH2 authorized_group=PAIRDROP_OAUTH2_AUTHORIZED_GROUP  enable_mtls_auth=PAIRDROP_MTLS_AUTH mtls_authorized_certs=PAIRDROP_MTLS_AUTHORIZED_CERTS homepage_labels_enable=PAIRDROP_HOMEPAGE_LABELS_ENABLE homepage_group_pairdrop=PAIRDROP_HOMEPAGE_GROUP_PAIRDROP homepage_name_pairdrop=PAIRDROP_HOMEPAGE_NAME_PAIRDROP homepage_icon_pairdrop=PAIRDROP_HOMEPAGE_ICON_PAIRDROP homepage_description_pairdrop=PAIRDROP_HOMEPAGE_DESCRIPTION_PAIRDROP homepage_show_stats_pairdrop=PAIRDROP_HOMEPAGE_SHOW_STATS_PAIRDROP homepage_widget_enable=PAIRDROP_HOMEPAGE_WIDGET_ENABLE homepage_widget_api_key=PAIRDROP_HOMEPAGE_WIDGET_API_KEY

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=pairdrop

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
