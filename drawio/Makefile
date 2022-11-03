ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} DRAWIO_TRAEFIK_HOST "Enter the drawio domain name" diagram.${ROOT_DOMAIN}

