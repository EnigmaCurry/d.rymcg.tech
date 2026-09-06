ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
	@${BIN}/reconfigure_ask ${ENV_FILE} BITMAGNET_TRAEFIK_HOST "Enter the bitmagnet domain name" bitmagnet${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} BITMAGNET_INSTANCE=$${instance:-default}
	@echo ""
	@${BIN}/reconfigure_wireguard_instance ${ENV_FILE} BITMAGNET_WIREGUARD_INSTANCE "Choose the wireguard instance to use as the default gateway"
	@echo ""
	@WG=$$(${BIN}/dotenv -f ${ENV_FILE} get BITMAGNET_WIREGUARD_INSTANCE); if [[ -n "$${WG}" ]]; then echo "## Finding the IPv4 address of wireguard instance: $${WG}" && ${BIN}/reconfigure ${ENV_FILE} BITMAGNET_WIREGUARD_ROUTER_IPV4=$$(docker exec wireguard_$${WG}-wireguard-1 ip -j -4 addr show dev eth0 | jq -r '.[0].addr_info[0].local') && echo; fi
	@WG=$$(${BIN}/dotenv -f ${ENV_FILE} get BITMAGNET_WIREGUARD_INSTANCE); if [[ -n "$${WG}" ]]; then echo "## Finding the IPv6 address of wireguard instance: $${WG}" && ${BIN}/reconfigure ${ENV_FILE} BITMAGNET_WIREGUARD_ROUTER_IPV6=$$(docker exec wireguard_$${WG}-wireguard-1 ip -j -6 addr show dev eth0 | jq -r '.[0].addr_info[0].local') && echo; fi
	@echo ""
	@${BIN}/reconfigure_auth ${ENV_FILE} BITMAGNET
	@${BIN}/reconfigure_password ${ENV_FILE} BITMAGNET_POSTGRES_PASSWORD 45
	@echo ""
	@echo "Bitmagnet can accumulate a lot of data - an estimate is 80GB for every 1,000,000 torrents. You can store the database in a bind mount on the host or in a Docker volume."
	@choices=('bind mount' 'Docker volume'); \
		[[ "$$(${BIN}/dotenv -f ${ENV_FILE} get BITMAGNET_USE_EXTERNAL_VOLUME)" == "false" ]] && default='Docker volume' || default='bind mount'; \
		answer=$$(eval "${BIN}/script-wizard choose 'Select whether you want to store the database in a bind mount on the host or in a Docker volume' $${choices[@]@Q} --default '$$default'"); \
		if [ "$$answer" = "bind mount" ]; then \
			${BIN}/reconfigure ${ENV_FILE} BITMAGNET_USE_EXTERNAL_VOLUME=true; \
			ALLOW_BLANK=0 ${BIN}/reconfigure_ask ${ENV_FILE} BITMAGNET_EXTERNAL_VOLUME "Enter the path on the host where you want store the database (e.g., \"/mnt/bitmagnet\" or \"~/bitmagnet\")." $$(${BIN}/dotenv -f "${ENV_FILE}" get "BITMAGNET_EXTERNAL_VOLUME"); \
		else \
			${BIN}/reconfigure ${ENV_FILE} BITMAGNET_USE_EXTERNAL_VOLUME=false; \
		fi
	@echo ""
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} BITMAGNET_TMDB_API_KEY "Optional: Enter your TMDB API key"
	@echo ""
	@${BIN}/reconfigure_ask ${ENV_FILE} BITMAGNET_IP_SOURCERANGE "Enter the allowed client IP source range (eg. 192.168.1.1/24 or 0.0.0.0/0)"
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:bitmagnet instance=@BITMAGNET_INSTANCE traefik_host=@BITMAGNET_TRAEFIK_HOST http_auth=BITMAGNET_HTTP_AUTH http_auth_var=@BITMAGNET_HTTP_AUTH ip_sourcerange=@BITMAGNET_IP_SOURCERANGE oauth2=BITMAGNET_OAUTH2 authorized_group=BITMAGNET_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=BITMAGNET_MTLS_AUTH mtls_authorized_certs=BITMAGNET_MTLS_AUTHORIZED_CERTS tmdb_api_key=BITMAGNET_TMDB_API_KEY homepage_labels_enable=BITMAGNET_HOMEPAGE_LABELS_ENABLE homepage_group_bitmagnet=BITMAGNET_HOMEPAGE_GROUP_BITMAGNET homepage_name_bitmagnet=BITMAGNET_HOMEPAGE_NAME_BITMAGNET homepage_icon_bitmagnet=BITMAGNET_HOMEPAGE_ICON_BITMAGNET homepage_description_bitmagnet=BITMAGNET_HOMEPAGE_DESCRIPTION_BITMAGNET homepage_show_stats_bitmagnet=BITMAGNET_HOMEPAGE_SHOW_STATS_BITMAGNET wireguard_instance=BITMAGNET_WIREGUARD_INSTANCE use_external_volume=BITMAGNET_USE_EXTERNAL_VOLUME external_volume=BITMAGNET_EXTERNAL_VOLUME

.PHONY: shell # Enter container shell
shell:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'bitmagnet' 'postgres' --default 'bitmagnet'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: build-hook-pre
build-hook-pre:
	@(echo "#!/usr/bin/env sh" && echo "### This file is generated by the Makefile's build-hook-pre target." && echo "### DO NOT EDIT this file." && echo "### Modify the source in ${BIN}/app-router-bootstrap-entrypoint.sh instead.") > bitmagnet/app-router-bootstrap.sh
	cat ${BIN}/app-router-bootstrap-entrypoint.sh >> bitmagnet/app-router-bootstrap.sh

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
