ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} INVIDIOUS_TRAEFIK_HOST "Enter the invidious domain name" yt.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} POSTGRES_PASSWORD=$(shell openssl rand -hex 45)
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} INVIDIOUS_HTTP_AUTH

