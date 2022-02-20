ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} XBS_TRAEFIK_HOST "Enter the xbs domain name" xbs.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} DB_PASSWORD=$(shell openssl rand -base64 45)
