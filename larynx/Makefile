ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} LARYNX_TRAEFIK_HOST "Enter the gitea domain name" larynx.${ROOT_DOMAIN}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} LARYNX_HTTP_AUTH

.PHONY: shell
shell:
	@docker-compose --env-file ${ENV_FILE} exec -it $${service:-app} /bin/sh -c "/bin/bash || /bin/sh"
