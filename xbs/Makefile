ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} XBS_TRAEFIK_HOST "Enter the xbs domain name" xbs.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} DB_PASSWORD=$(shell openssl rand -base64 45)

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -it api /bin/sh"
