ROOT_DIR = ..
include ../_scripts/Makefile.projects-no-open
include ../_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} TIDDLYWIKI_NODEJS_TRAEFIK_HOST "Enter the tiddlywiki domain name" wiki${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} TIDDLYWIKI_NODEJS_INSTANCE=${instance}
	@echo ""
	@echo "Configure the admin account credentials:"
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} TIDDLYWIKI_NODEJS_HTTP_AUTH
	@echo ""
	@${BIN}/confirm $$([[ "$$(${BIN}/dotenv -f ${ENV_FILE} get TIDDLYWIKI_PUBLIC_IP_SOURCERANGE)" == "0.0.0.0/0" ]] && echo "yes" || echo "no") "Do you want to enable public read-only access" "?" && ${BIN}/reconfigure ${ENV_FILE} TIDDLYWIKI_PUBLIC_IP_SOURCERANGE=0.0.0.0/0 || ${BIN}/reconfigure ${ENV_FILE} TIDDLYWIKI_PUBLIC_IP_SOURCERANGE=0.0.0.0/32
	@echo ""
	@echo "Enter your S3 bucket credentials:"
	@${BIN}/reconfigure_ask ${ENV_FILE} TIDDLYWIKI_NODEJS_S3_BUCKET "Enter the S3 Bucket name" wiki${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} TIDDLYWIKI_NODEJS_S3_ENDPOINT "Enter the S3 Endpoint domain name" s3.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} TIDDLYWIKI_NODEJS_S3_ACCESS_KEY_ID "Enter the S3 Access ID" wiki${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} TIDDLYWIKI_NODEJS_S3_SECRET_KEY "Enter the S3 Secret Key"


.PHONY: shell
shell:
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec tiddlywiki-nodejs /bin/sh"

# .PHONY: override-hook
# override-hook:
# 	@${BIN}/docker_compose_override ${ENV_FILE} TIDDLYWIKI_NODEJS_PUBLIC_HTTP_AUTH

.PHONY: ssh-keygen
ssh-keygen:
	@export DOCKER_COMPOSE_PROFILES=git-autocommit; make --no-print-directory build; make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="run --rm -it git-autocommit ssh-keygen"

.PHONY: open
open:
	@export DOCKER_CONTEXT=${DOCKER_CONTEXT} ENV_FILE=${ENV_FILE} CONTEXT_INSTANCE=${CONTEXT_INSTANCE}; ${BIN}/open /login
