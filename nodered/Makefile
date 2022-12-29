ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} NODERED_TRAEFIK_HOST "Enter the nodered domain name" nodered.${ROOT_DOMAIN}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} NODERED_HTTP_AUTH

