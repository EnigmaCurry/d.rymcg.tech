ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask PIWIGO_TRAEFIK_HOST "Enter the piwigo domain name" pics.${ROOT_DOMAIN}
	@${BIN}/reconfigure MARIADB_ROOT_PASSWORD=$(shell openssl rand -base64 45)
	@${BIN}/reconfigure MARIADB_PASSWORD=$(shell openssl rand -base64 45)
	@${BIN}/reconfigure_ask TIMEZONE "Enter your timezone" UTC
