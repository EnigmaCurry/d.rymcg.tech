ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} BAIKAL_TRAEFIK_HOST "Enter the baikal domain name" cal.${ROOT_DOMAIN}

