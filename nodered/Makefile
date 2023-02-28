ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} NODERED_TRAEFIK_HOST "Enter the nodered domain name" nodered${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} NODERED_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} NODERED_HTTP_AUTH
