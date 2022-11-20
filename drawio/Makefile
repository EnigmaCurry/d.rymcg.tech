ROOT_DIR = ..
include ../_scripts/Makefile.projects
include ../_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} DRAWIO_INSTANCE=${instance}
	@${BIN}/reconfigure_ask ${ENV_FILE} DRAWIO_TRAEFIK_HOST "Enter the drawio domain name" diagram${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}

