ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook # Configure .env file
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} WHOAMI_TRAEFIK_HOST "Enter the whoami domain name" whoami.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} WHOAMI_NAME "Enter a unique name to display in all responses" $$(${BIN}/dotenv -f ${ENV_FILE} get WHOAMI_TRAEFIK_HOST)

