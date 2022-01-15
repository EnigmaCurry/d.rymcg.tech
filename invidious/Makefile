ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask INVIDIOUS_TRAEFIK_HOST "Enter the invidious domain name" yt.${ROOT_DOMAIN}
	@${BIN}/reconfigure POSTGRES_PASSWORD=$(shell openssl rand -hex 45)
	@${BIN}/reconfigure_htpasswd INVIDIOUS_HTTP_AUTH

