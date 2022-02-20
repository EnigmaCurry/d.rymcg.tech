ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} LARYNX_TRAEFIK_HOST "Enter the gitea domain name" larynx.${ROOT_DOMAIN}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} LARYNX_HTTP_AUTH

