ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook # Configure .env file
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} SHAARLI_TRAEFIK_HOST "Enter the shaarli domain name" shaarli.${ROOT_DOMAIN}

