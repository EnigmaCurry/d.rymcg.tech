ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} WHOAMI_TRAEFIK_HOST "Enter the whoami domain name" whoami${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} WHOAMI_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} WHOAMI
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:whoami instance=@WHOAMI_INSTANCE traefik_host=@WHOAMI_TRAEFIK_HOST http_auth=WHOAMI_HTTP_AUTH http_auth_var=@WHOAMI_HTTP_AUTH ip_sourcerange=@WHOAMI_IP_SOURCERANGE oauth2=WHOAMI_OAUTH2 authorized_group=WHOAMI_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=WHOAMI_MTLS_AUTH mtls_authorized_certs=WHOAMI_MTLS_AUTHORIZED_CERTS homepage_labels_enable=WHOAMI_HOMEPAGE_LABELS_ENABLE homepage_group_whoami=WHOAMI_HOMEPAGE_GROUP_WHOAMI homepage_name_whoami=WHOAMI_HOMEPAGE_NAME_WHOAMI homepage_icon_whoami=WHOAMI_HOMEPAGE_ICON_WHOAMI homepage_description_whoami=WHOAMI_HOMEPAGE_DESCRIPTION_WHOAMI homepage_show_stats_whoami=WHOAMI_HOMEPAGE_SHOW_STATS_WHOAMI homepage_widget_enable=WHOAMI_HOMEPAGE_WIDGET_ENABLE

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=whoami

.PHONY: shell-menu
shell-menu:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'whoami' --default 'whoami'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo

