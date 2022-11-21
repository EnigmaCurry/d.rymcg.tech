ROOT_DIR = ..
include ../_scripts/Makefile.projects-no-open
include ../_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} TIDLYWIKI_TRAEFIK_HOST "Enter the tidlywiki domain name" wiki${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} TIDLYWIKI_INSTANCE=${instance}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} TIDLYWIKI_HTTP_AUTH
.PHONY: shell
shell:
	@make --no-print-directory docker-compose EXTRA_ARGS="exec tidlywiki /bin/sh"
open:
	@export DOCKER_CONTEXT=${DOCKER_CONTEXT} ENV_FILE=${ENV_FILE} CONTEXT_INSTANCE=${CONTEXT_INSTANCE}; ${BIN}/open /admin
