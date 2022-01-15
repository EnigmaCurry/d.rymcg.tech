ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask XBS_TRAEFIK_HOST "Enter the xbs domain name" xbs.${ROOT_DOMAIN}
	@${BIN}/reconfigure DB_PASSWORD=$(shell openssl rand -base64 45)
