ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} NODERED_TRAEFIK_HOST "Enter the nodered domain name" nodered.${ROOT_DOMAIN}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} NODERED_HTTP_AUTH

