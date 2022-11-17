ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} FILESTASH_TRAEFIK_HOST "Enter the filestash domain name" filestash.${ROOT_DOMAIN}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} FILESTASH_AUTH

.PHONY: admin # Open the admin page
admin:
	@${BIN}/open /admin

