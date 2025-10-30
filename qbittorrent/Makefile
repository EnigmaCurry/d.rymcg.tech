ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} QBITTORRENT_INSTANCE=${instance}
	@${BIN}/reconfigure ${ENV_FILE} QBITTORRENT_DOCKER_CONTEXT=${DOCKER_CONTEXT}
	@echo ""
	@${BIN}/reconfigure_network_mode ${ENV_FILE} QBITTORRENT_NETWORK_MODE "Choose the network mode for this container (default or wireguard)"
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_TRAEFIK_HOST "Enter the qbittorrent domain name" qbittorrent${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_PEER_PORT "Enter the public peer port qbittorrent should bind"
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_UID "Enter the qbittorrent user ID (UID) for all file permissions"
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_GID "Enter the qbittorrent group ID (GID) for all file permissions"
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_DOWNLOAD_VOLUME "Enter the absolute host path to store downloads"
	@echo ""
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_IP_SOURCERANGE "Enter the allowed client IP source range (eg. 192.168.1.1/24 or 0.0.0.0/0)"
	@${BIN}/reconfigure_auth ${ENV_FILE} QBITTORRENT

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=qbittorrent

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:qbitorrent instance=@QBITTORRENT_INSTANCE traefik_host=@QBITTORRENT_TRAEFIK_HOST http_auth=QBITTORRENT_HTTP_AUTH http_auth_var=@QBITTORRENT_HTTP_AUTH ip_sourcerange=@QBITTORRENT_IP_SOURCERANGE oauth2=QBITTORRENT_OAUTH2 authorized_group=QBITTORRENT_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=QBITTORRENT_MTLS_AUTH mtls_authorized_certs=QBITTORRENT_MTLS_AUTHORIZED_CERTS homepage_labels_enable=QBITTORRENT_HOMEPAGE_LABELS_ENABLE homepage_group_qbittorrent=QBITTORRENT_HOMEPAGE_GROUP_QBITTORRENT homepage_name_qbittorrent=QBITTORRENT_HOMEPAGE_NAME_QBITTORRENT homepage_icon_qbittorrent=QBITTORRENT_HOMEPAGE_ICON_QBITTORRENT homepage_description_qbittorrent=QBITTORRENT_HOMEPAGE_DESCRIPTION_QBITTORRENT homepage_show_stats_qbittorrent=QBITTORRENT_HOMEPAGE_SHOW_STATS_QBITTORRENT network_mode=QBITTORRENT_NETWORK_MODE

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo

.PHONY: copy-categories # Copy categories-dist.json for your current Docker context and instance
copy-categories:
	@[[ -f "qbittorrent-config/categories_${DOCKER_CONTEXT}_${INSTANCE}.json" ]] && echo "\`qbittorrent-config/categories_${DOCKER_CONTEXT}_${INSTANCE}.json\` already exists." || \
		cp qbittorrent-config/categories-dist.json qbittorrent-config/categories_${DOCKER_CONTEXT}_${INSTANCE}.json
