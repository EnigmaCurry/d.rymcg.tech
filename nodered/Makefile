ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask NODERED_TRAEFIK_HOST "Enter the nodered domain name" nodered.${ROOT_DOMAIN}
	@${BIN}/reconfigure_htpasswd NODERED_HTTP_AUTH

