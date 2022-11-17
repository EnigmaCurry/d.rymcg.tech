ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@SUFFIX=$$(test -z "$${instance}" && echo "" || echo "-$${instance}"); ${BIN}/reconfigure_ask ${ENV_FILE} WHOAMI_TRAEFIK_HOST "Enter the whoami domain name" whoami$${SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} WHOAMI_NAME "Enter a unique name to display in all responses" $${instance:-whoami}
	@${BIN}/reconfigure ${ENV_FILE} WHOAMI_INSTANCE=$${instance:-default}
