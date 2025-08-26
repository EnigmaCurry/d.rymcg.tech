ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} ICECAST_TRAEFIK_HOST "Enter the icecast domain name" icecast${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} ICECAST_IP_SOURCERANGE "Enter the icecast IP address CIDR filter (0.0.0.0/0 for no filter)"
	@${BIN}/reconfigure_ask ${ENV_FILE} ICECAST_LOCATION "Enter the server location"
	@${BIN}/reconfigure_ask ${ENV_FILE} ICECAST_ADMIN "Enter the admin email address"
	@${BIN}/reconfigure ${ENV_FILE} ICECAST_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_password ${ENV_FILE} ICECAST_AUTHENTICATION_SOURCE_PASSWORD
	@${BIN}/reconfigure_password ${ENV_FILE} ICECAST_AUTHENTICATION_RELAY_PASSWORD
	@${BIN}/reconfigure_password ${ENV_FILE} ICECAST_AUTHENTICATION_ADMIN_PASSWORD

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=icecast

.PHONY: override-hook
override-hook:
	@${BIN}/docker_compose_override ${ENV_FILE} icecast_allow_direct_map_port=ICECAST_ALLOW_DIRECT_MAP_PORT icecast_direct_map_port=ICECAST_DIRECT_MAP_PORT

.PHONY: install-hook
install-hook:
	@echo
