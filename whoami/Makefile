ROOT_DIR = ..
include ../_scripts/Makefile.projects
include ../_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} WHOAMI_TRAEFIK_HOST "Enter the whoami domain name" whoami${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} WHOAMI_NAME "Enter a unique name to display in all responses" $${instance:-whoami}
	@${BIN}/reconfigure ${ENV_FILE} WHOAMI_INSTANCE=$${instance:-default}
