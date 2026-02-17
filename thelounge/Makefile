ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} THELOUNGE_TRAEFIK_HOST "Enter the thelounge domain name" thelounge${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} THELOUNGE_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} THELOUNGE
	@${BIN}/confirm $$(${BIN}/dotenv -f ${ENV_FILE} get THELOUNGE_INSPIRCD_NETWORK_CONNECT) "Do you want Soju to connect to the local InspIRCd network? (This is required if you deploy Soju and InspIRCd on the same Docker host)" && ${BIN}/reconfigure ${ENV_FILE} THELOUNGE_INSPIRCD_NETWORK_CONNECT=true || ${BIN}/reconfigure ${ENV_FILE} THELOUNGE_INSPIRCD_NETWORK_CONNECT=false
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:thelounge instance=@THELOUNGE_INSTANCE traefik_host=@THELOUNGE_TRAEFIK_HOST http_auth=THELOUNGE_HTTP_AUTH http_auth_var=@THELOUNGE_HTTP_AUTH ip_sourcerange=@THELOUNGE_IP_SOURCERANGE oauth2=THELOUNGE_OAUTH2 authorized_group=THELOUNGE_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=THELOUNGE_MTLS_AUTH mtls_authorized_certs=THELOUNGE_MTLS_AUTHORIZED_CERTS homepage_labels_enable=THELOUNGE_HOMEPAGE_LABELS_ENABLE homepage_group_thelounge=THELOUNGE_HOMEPAGE_GROUP_THELOUNGE homepage_name_thelounge=THELOUNGE_HOMEPAGE_NAME_THELOUNGE homepage_icon_thelounge=THELOUNGE_HOMEPAGE_ICON_THELOUNGE homepage_description_thelounge=THELOUNGE_HOMEPAGE_DESCRIPTION_THELOUNGE homepage_show_stats_thelounge=THELOUNGE_HOMEPAGE_SHOW_STATS_THELOUNGE homepage_widget_enable=THELOUNGE_HOMEPAGE_WIDGET_ENABLE inspircd_network_connect=THELOUNGE_INSPIRCD_NETWORK_CONNECT inspircd_network_name=THELOUNGE_INSPIRCD_NETWORK_NAME traefik_entrypoint=THELOUNGE_TRAEFIK_ENTRYPOINT

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=thelounge

.PHONY: shell-menu
shell-menu:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'thelounge' --default 'thelounge'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo

.PHONY: create-user
create-user:
	@export USERNAME="$$(${BIN}/script-wizard ask 'Enter the username to create')"; echo $${USERNAME}; make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="run --rm thelounge thelounge add $${USERNAME}"
	@echo
	@echo Remember to restart the service.
