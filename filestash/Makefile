ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} FILESTASH_TRAEFIK_HOST "Enter the filestash domain name" filestash${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} FILESTASH_INSTANCE=${instance}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} FILESTASH_AUTH

.PHONY: admin # Open the admin page
admin:
	@${BIN}/open /admin

