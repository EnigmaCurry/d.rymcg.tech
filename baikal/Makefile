ROOT_DIR = ..
include ../_scripts/Makefile.projects
include ../_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} BAIKAL_INSTANCE=${instance}
	@${BIN}/reconfigure_ask ${ENV_FILE} BAIKAL_TRAEFIK_HOST "Enter the baikal domain name" cal${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}

