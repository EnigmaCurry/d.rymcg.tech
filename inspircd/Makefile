ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} INSPIRCD_TRAEFIK_HOST "Enter the InspIRCd domain name" irc${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} INSPIRCD_SERVER_HOSTNAME=$$(${BIN}/dotenv -f ${ENV_FILE} get INSPIRCD_TRAEFIK_HOST | cut -d. -f1)
	@${BIN}/reconfigure ${ENV_FILE} INSPIRCD_NET_SUFFIX=.$$(${BIN}/dotenv -f ${ENV_FILE} get INSPIRCD_TRAEFIK_HOST | cut -d. -f2-)
	@${BIN}/reconfigure_ask ${ENV_FILE} INSPIRCD_NET_NAME "Enter the InspIRCd adhoc network name"
	@${BIN}/reconfigure_ask ${ENV_FILE} INSPIRCD_ADMIN_NAME "Enter the full name of the administrator" "Adam Inistrator"
	@${BIN}/reconfigure_ask ${ENV_FILE} INSPIRCD_ADMIN_EMAIL "Enter the email address of the administrator" "noreply@this.is.an.example.com"
	@${BIN}/reconfigure_ask ${ENV_FILE} INSPIRCD_ADMIN_DESC "Enter the description for the administrator" "Supreme Overlord"
	@echo
	@${BIN}/confirm no "Do you want to make this server public? (No connection password required)" && ${BIN}/reconfigure ${ENV_FILE} INSPIRCD_CONNECT_PASSWORD= || ${BIN}/reconfigure_password_bcrypt ${ENV_FILE} INSPIRCD_CONNECT_PASSWORD
	@echo
	@${BIN}/reconfigure ${ENV_FILE} INSPIRCD_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} INSPIRCD
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:inspircd instance=@INSPIRCD_INSTANCE traefik_host=@INSPIRCD_TRAEFIK_HOST ip_sourcerange=@INSPIRCD_IP_SOURCERANGE enable_mtls_auth=INSPIRCD_MTLS_AUTH mtls_authorized_certs=INSPIRCD_MTLS_AUTHORIZED_CERTS homepage_labels_enable=INSPIRCD_HOMEPAGE_LABELS_ENABLE homepage_group_inspircd=INSPIRCD_HOMEPAGE_GROUP_INSPIRCD homepage_name_inspircd=INSPIRCD_HOMEPAGE_NAME_INSPIRCD homepage_icon_inspircd=INSPIRCD_HOMEPAGE_ICON_INSPIRCD homepage_description_inspircd=INSPIRCD_HOMEPAGE_DESCRIPTION_INSPIRCD homepage_show_stats_inspircd=INSPIRCD_HOMEPAGE_SHOW_STATS_INSPIRCD homepage_widget_enable=INSPIRCD_HOMEPAGE_WIDGET_ENABLE

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=inspircd

.PHONY: shell-menu
shell-menu:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'inspircd' --default 'inspircd'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo

