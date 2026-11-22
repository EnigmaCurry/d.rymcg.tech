ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} SOJU_TRAEFIK_HOST "Enter the soju domain name" irc${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} SOJU_TITLE "Enter the title for your Soju instance" $$(${BIN}/dotenv -f ${ENV_FILE} get SOJU_TRAEFIK_HOST)
	@${BIN}/reconfigure ${ENV_FILE} SOJU_INSTANCE=$${instance:-default}
	@echo
	@${BIN}/confirm $$(${BIN}/dotenv -f ${ENV_FILE} get SOJU_INSPIRCD_NETWORK_CONNECT) "Do you want Soju to connect to the local InspIRCd network? (This is required if you deploy Soju and InspIRCd on the same Docker host)" && ${BIN}/reconfigure ${ENV_FILE} SOJU_INSPIRCD_NETWORK_CONNECT=true || ${BIN}/reconfigure ${ENV_FILE} SOJU_INSPIRCD_NETWORK_CONNECT=false
	@echo

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:soju instance=@SOJU_INSTANCE traefik_host=@SOJU_TRAEFIK_HOST ip_sourcerange=@SOJU_IP_SOURCERANGE enable_mtls_auth=SOJU_MTLS_AUTH mtls_authorized_certs=SOJU_MTLS_AUTHORIZED_CERTS homepage_labels_enable=SOJU_HOMEPAGE_LABELS_ENABLE homepage_group_soju=SOJU_HOMEPAGE_GROUP_SOJU homepage_name_soju=SOJU_HOMEPAGE_NAME_SOJU homepage_icon_soju=SOJU_HOMEPAGE_ICON_SOJU homepage_description_soju=SOJU_HOMEPAGE_DESCRIPTION_SOJU homepage_show_stats_soju=SOJU_HOMEPAGE_SHOW_STATS_SOJU homepage_widget_enable=SOJU_HOMEPAGE_WIDGET_ENABLE inspircd_network_connect=SOJU_INSPIRCD_NETWORK_CONNECT inspircd_network_name=SOJU_INSPIRCD_NETWORK_NAME traefik_entrypoint=SOJU_TRAEFIK_ENTRYPOINT traefik_tls=SOJU_TRAEFIK_TLS

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=soju

.PHONY: shell-menu
shell-menu:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'soju' --default 'soju'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo


.PHONY: create-admin
create-admin:
	@export USERNAME="$$(${BIN}/script-wizard ask 'Enter the username to create')"; echo $${USERNAME}; make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="run --rm soju sojudb create-user $${USERNAME} -admin"
	@echo
	@echo Remember to restart the service.
