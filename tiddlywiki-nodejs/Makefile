ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-no-open
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: build-hook-pre
build-hook-pre:
	@make --no-print-directory build service=tiddlywiki-base NO_HOOKS=true

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} TIDDLYWIKI_NODEJS_TRAEFIK_HOST "Enter the tiddlywiki domain name" wiki${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} TIDDLYWIKI_NODEJS_INSTANCE=${instance}
	@${BIN}/reconfigure_auth ${ENV_FILE} TIDDLYWIKI_NODEJS required
	@echo ""
	@${BIN}/confirm $$([[ "$$(${BIN}/dotenv -f ${ENV_FILE} get TIDDLYWIKI_PUBLIC_IP_SOURCERANGE)" == "0.0.0.0/0" ]] && echo "yes" || echo "no") "Do you want to enable public read-only access" "?" && ${BIN}/reconfigure ${ENV_FILE} TIDDLYWIKI_PUBLIC_IP_SOURCERANGE=0.0.0.0/0 || ${BIN}/reconfigure ${ENV_FILE} TIDDLYWIKI_PUBLIC_IP_SOURCERANGE=0.0.0.0/32
	@echo ""
	@echo "Enter your S3 bucket credentials:"
	@${BIN}/reconfigure_ask ${ENV_FILE} TIDDLYWIKI_NODEJS_S3_BUCKET "Enter the S3 Bucket name" $$(${BIN}/dotenv -f ${ENV_FILE} get TIDDLYWIKI_NODEJS_TRAEFIK_HOST)
	@${BIN}/reconfigure_ask ${ENV_FILE} TIDDLYWIKI_NODEJS_S3_ENDPOINT "Enter the S3 Endpoint domain name" s3.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} TIDDLYWIKI_NODEJS_S3_ACCESS_KEY_ID "Enter the S3 Access ID" $$(${BIN}/dotenv -f ${ENV_FILE} get TIDDLYWIKI_NODEJS_TRAEFIK_HOST)
	@${BIN}/reconfigure_ask ${ENV_FILE} TIDDLYWIKI_NODEJS_S3_SECRET_KEY "Enter the S3 Secret Key"
	@echo ""
	@echo "There are optional plugins for markdown and tiddlymap,"
	@echo "but to use them you must configure TIDDLYWIKI_NODEJS_PLUGINS in the .env file."
	@echo ""

.PHONY: override-hook
override-hook:
#### This sets the override template variables for docker-compose.instance.yaml:
#### The template dynamically renders to docker-compose.override_{DOCKER_CONTEXT}_{INSTANCE}.yaml
#### These settings are used to automatically generate the service container labels, and traefik config, inside the template.
#### The variable arguments have three forms: `=` `=:` `=@`
####   name=VARIABLE_NAME    # sets the template 'name' field to the value of VARIABLE_NAME found in the .env file
####                         # (this hardcodes the value into docker-compose.override.yaml)
####   name=:VARIABLE_NAME   # sets the template 'name' field to the literal string 'VARIABLE_NAME'
####                         # (this hardcodes the string into docker-compose.override.yaml)
####   name=@VARIABLE_NAME   # sets the template 'name' field to the literal string '${VARIABLE_NAME}'
####                         # (used for regular docker-compose expansion of env vars by name.)
	@${BIN}/docker_compose_override ${ENV_FILE} project=:tiddlywiki-nodejs instance=@TIDDLYWIKI_NODEJS_INSTANCE traefik_host=@TIDDLYWIKI_NODEJS_TRAEFIK_HOST http_auth=TIDDLYWIKI_NODEJS_HTTP_AUTH http_auth_var=@TIDDLYWIKI_NODEJS_HTTP_AUTH ip_sourcerange=@TIDDLYWIKI_NODEJS_IP_SOURCERANGE oauth2=TIDDLYWIKI_NODEJS_OAUTH2 authorized_group=TIDDLYWIKI_NODEJS_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=TIDDLYWIKI_NODEJS_MTLS_AUTH mtls_authorized_certs=TIDDLYWIKI_NODEJS_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=$${SERVICE:-tiddlywiki-nodejs}

.PHONY: watcher-shell
watcher-shell:
	@make --no-print-directory docker-compose-shell SERVICE=$${SERVICE:-watcher}

# .PHONY: override-hook
# override-hook:
# 	@${BIN}/docker_compose_override ${ENV_FILE}

.PHONY: ssh-keygen
ssh-keygen:
	@export DOCKER_COMPOSE_PROFILES=git-autocommit; make --no-print-directory build; make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="run --rm -it git-autocommit ssh-keygen"

.PHONY: open
open:
	@export DOCKER_CONTEXT=${DOCKER_CONTEXT} ENV_FILE=${ENV_FILE} CONTEXT_INSTANCE=${CONTEXT_INSTANCE}; ${BIN}/open /login

.PHONY: backup # Backup TiddlyWiki to TIDDLYWIKI_NODEJS_LOCAL_BACKUP_DIR
backup:
	@[[ "$$(${BIN}/dotenv -f ${ENV_FILE} get TIDDLYWIKI_NODEJS_LOCAL_BACKUP_DIR)" == "" ]] && echo "Missing TIDDLYWIKI_NODEJS_LOCAL_BACKUP_DIR environment variable" && exit 1 || true
	@${BIN}/backup_volume "${PROJECT_VOLUME_PREFIX}_data" "$$(${BIN}/dotenv -f ${ENV_FILE} get TIDDLYWIKI_NODEJS_LOCAL_BACKUP_DIR)" tiddlywiki.info

