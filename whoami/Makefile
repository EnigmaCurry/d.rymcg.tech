ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} WHOAMI_TRAEFIK_HOST "Enter the whoami domain name" whoami.${ROOT_DOMAIN}
