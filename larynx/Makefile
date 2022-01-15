ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask LARYNX_TRAEFIK_HOST "Enter the gitea domain name" larynx.${ROOT_DOMAIN}
	@${BIN}/reconfigure_htpasswd LARYNX_HTTP_AUTH

