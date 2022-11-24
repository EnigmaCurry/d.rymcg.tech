ROOT_DIR = ..
include ../_scripts/Makefile.projects-no-open
include ../_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} TIDDLYWIKI_TRAEFIK_HOST "Enter the tiddlywiki domain name" wiki${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} TIDDLYWIKI_INSTANCE=${instance}
	@echo ""
	@echo "Configure the admin account credentials:"
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} TIDDLYWIKI_ADMIN_HTTP_AUTH
	@echo ""
	@${BIN}/confirm $$([[ "$$(${BIN}/dotenv -f ${ENV_FILE} get TIDDLYWIKI_PUBLIC_IP_SOURCERANGE)" == "0.0.0.0/0" ]] && echo "yes" || echo "no") "Do you want to enable public read-only access" "?" && ${BIN}/reconfigure ${ENV_FILE} TIDDLYWIKI_PUBLIC_IP_SOURCERANGE=0.0.0.0/0 || (${BIN}/reconfigure ${ENV_FILE} TIDDLYWIKI_PUBLIC_IP_SOURCERANGE=0.0.0.0/32 && ${BIN}/reconfigure ${ENV_FILE} TIDDLYWIKI_PUBLIC_HTTP_AUTH="")
	@[[ "$$(${BIN}/dotenv -f ${ENV_FILE} get TIDDLYWIKI_PUBLIC_IP_SOURCERANGE)" == "0.0.0.0/32" ]] || (${BIN}/confirm $$([[ "$$(${BIN}/dotenv -f ${ENV_FILE} get TIDDLYWIKI_PUBLIC_HTTP_AUTH)" == "" ]] && echo "no" || echo "yes") "Should public read-only access require a password" "?" && ${BIN}/reconfigure_htpasswd ${ENV_FILE} TIDDLYWIKI_PUBLIC_HTTP_AUTH || ${BIN}/reconfigure ${ENV_FILE} TIDDLYWIKI_PUBLIC_HTTP_AUTH="")

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec tiddlywiki /bin/sh"

.PHONY: open
open:
	@export DOCKER_CONTEXT=${DOCKER_CONTEXT} ENV_FILE=${ENV_FILE} CONTEXT_INSTANCE=${CONTEXT_INSTANCE}; ${BIN}/open /editor

.PHONY: override-hook
override-hook:
	@${BIN}/docker_compose_override ${ENV_FILE} TIDDLYWIKI_PUBLIC_HTTP_AUTH

.PHONY: ssh-keygen
ssh-keygen:
	@export DOCKER_COMPOSE_PROFILES=git-autocommit; make --no-print-directory build; make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="run --rm -it git-autocommit ssh-keygen"
