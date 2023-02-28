ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} XBS_TRAEFIK_HOST "Enter the xbs domain name" xbs${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_password ${ENV_FILE} XBS_DB_PASSWORD

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -it api /bin/sh"
