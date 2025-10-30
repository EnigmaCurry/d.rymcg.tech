ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} ARIA2_INSTANCE=${instance}

	@echo ""
	@${BIN}/reconfigure_network_mode ${ENV_FILE} ARIA2_NETWORK_MODE "Choose the network mode for this container (default or wireguard)"
	@${BIN}/reconfigure_ask ${ENV_FILE} ARIA2_TRAEFIK_HOST "Enter the aria2 domain name" aria2${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} ARIA2_DOWNLOAD_VOLUME "Enter the absolute host path to store downloads"
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} ARIA2_UID "Enter the aria2 user ID (UID) for all file permissions"
	@${BIN}/reconfigure_ask ${ENV_FILE} ARIA2_GID "Enter the aria2 group ID (GID) for all file permissions"
	@echo
	@${BIN}/reconfigure_password ${ENV_FILE} ARIA2_RPC_SECRET
	@${BIN}/reconfigure_ask ${ENV_FILE} ARIA2_IP_SOURCERANGE "Enter the allowed client IP source range (eg. 192.168.1.1/24 or 0.0.0.0/0)"
	@${BIN}/reconfigure_auth ${ENV_FILE} ARIA2


.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=aria2

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:aria2 instance=@ARIA2_INSTANCE traefik_host=@ARIA2_TRAEFIK_HOST http_auth=ARIA2_HTTP_AUTH http_auth_var=@ARIA2_HTTP_AUTH ip_sourcerange=@ARIA2_IP_SOURCERANGE oauth2=ARIA2_OAUTH2 authorized_group=ARIA2_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=ARIA2_MTLS_AUTH mtls_authorized_certs=ARIA2_MTLS_AUTHORIZED_CERTS homepage_labels_enable=ARIA2_HOMEPAGE_LABELS_ENABLE homepage_group_aria2=ARIA2_HOMEPAGE_GROUP_ARIA2 homepage_name_aria2=ARIA2_HOMEPAGE_NAME_ARIA2 homepage_icon_aria2=ARIA2_HOMEPAGE_ICON_ARIA2 homepage_description_aria2=ARIA2_HOMEPAGE_DESCRIPTION_ARIA2 homepage_show_stats_aria2=ARIA2_HOMEPAGE_SHOW_STATS_ARIA2 web_port=ARIA2_WEB_PORT rpc_port=ARIA2_RPC_PORT network_mode=ARIA2_NETWORK_MODE


.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
