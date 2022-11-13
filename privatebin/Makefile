ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook # Configure .env file
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} PRIVATEBIN_TRAEFIK_HOST "Enter the privatebin domain name" bin.${ROOT_DOMAIN}
