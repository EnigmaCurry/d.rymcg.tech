ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure ${ENV_FILE} FIREFOX_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_network_mode ${ENV_FILE} FIREFOX_NETWORK_MODE "Choose the network mode for this container (default or wireguard)"
	@${BIN}/reconfigure_ask ${ENV_FILE} FIREFOX_TRAEFIK_HOST "Enter the firefox domain name" firefox${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_auth ${ENV_FILE} FIREFOX
	@echo ""

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:firefox instance=@FIREFOX_INSTANCE traefik_host=@FIREFOX_TRAEFIK_HOST http_auth=FIREFOX_HTTP_AUTH http_auth_var=@FIREFOX_HTTP_AUTH ip_sourcerange=@FIREFOX_IP_SOURCERANGE oauth2=FIREFOX_OAUTH2 authorized_group=FIREFOX_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=FIREFOX_MTLS_AUTH mtls_authorized_certs=FIREFOX_MTLS_AUTHORIZED_CERTS homepage_labels_enable=FIREFOX_HOMEPAGE_LABELS_ENABLE homepage_group_firefox=FIREFOX_HOMEPAGE_GROUP_FIREFOX homepage_name_firefox=FIREFOX_HOMEPAGE_NAME_FIREFOX homepage_icon_firefox=FIREFOX_HOMEPAGE_ICON_FIREFOX homepage_description_firefox=FIREFOX_HOMEPAGE_DESCRIPTION_FIREFOX homepage_show_stats_firefox=FIREFOX_HOMEPAGE_SHOW_STATS_FIREFOX network_mode=FIREFOX_NETWORK_MODE

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=firefox

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo

