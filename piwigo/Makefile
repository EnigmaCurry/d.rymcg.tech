ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} PIWIGO_TRAEFIK_HOST "Enter the piwigo domain name" pics.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} MARIADB_ROOT_PASSWORD=$(shell openssl rand -base64 45)
	@${BIN}/reconfigure ${ENV_FILE} MARIADB_PASSWORD=$(shell openssl rand -base64 45)
	@${BIN}/reconfigure_ask ${ENV_FILE} TIMEZONE "Enter your timezone" UTC
