ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} SYNCTHING_TRAEFIK_HOST "Enter the syncthing domain name" syncthing${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} SYNCTHING_INSTANCE=$${instance:-default}
	@echo
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get SYNCTHING_ADMIN_ENABLE)" == 'false' && echo no || echo yes) "Do you want to enable the admin console" "?" && ( \
		${BIN}/reconfigure ${ENV_FILE} SYNCTHING_ADMIN_ENABLE=true; \
		echo "The next few questions about auth is about the ADMIN page ONLY ::"; \
		${BIN}/reconfigure_auth ${ENV_FILE} SYNCTHING_ADMIN; \
	) || ( \
		${BIN}/reconfigure ${ENV_FILE} SYNCTHING_ADMIN_ENABLE=false; \
	)
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:syncthing instance=@SYNCTHING_INSTANCE traefik_host=@SYNCTHING_TRAEFIK_HOST http_auth=SYNCTHING_ADMIN_HTTP_AUTH http_auth_var=@SYNCTHING_ADMIN_HTTP_AUTH ip_sourcerange=@SYNCTHING_IP_SOURCERANGE admin_ip_sourcerange=@SYNCTHING_ADMIN_IP_SOURCERANGE oauth2=SYNCTHING_ADMIN_OAUTH2 authorized_group=SYNCTHING_ADMIN_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=SYNCTHING_ADMIN_MTLS_AUTH mtls_authorized_certs=SYNCTHING_ADMIN_MTLS_AUTHORIZED_CERTS homepage_labels_enable=SYNCTHING_HOMEPAGE_LABELS_ENABLE homepage_group_syncthing=SYNCTHING_HOMEPAGE_GROUP_SYNCTHING homepage_name_syncthing=SYNCTHING_HOMEPAGE_NAME_SYNCTHING homepage_icon_syncthing=SYNCTHING_HOMEPAGE_ICON_SYNCTHING homepage_description_syncthing=SYNCTHING_HOMEPAGE_DESCRIPTION_SYNCTHING homepage_show_stats_syncthing=SYNCTHING_HOMEPAGE_SHOW_STATS_SYNCTHING homepage_widget_enable=SYNCTHING_HOMEPAGE_WIDGET_ENABLE homepage_widget_api_key=SYNCTHING_HOMEPAGE_WIDGET_API_KEY admin_enable=SYNCTHING_ADMIN_ENABLE

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=syncthing

.PHONY: shell-menu
shell-menu:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'syncthing' --default 'syncthing'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo

