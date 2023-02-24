ROOT_DIR = ../..
include ${ROOT_DIR}/_scripts/Makefile.help
include ${ROOT_DIR}/_scripts/Makefile.globals
include ${ROOT_DIR}/_scripts/Makefile.docker-compose
include ${ROOT_DIR}/_scripts/Makefile.clean
include ${ROOT_DIR}/_scripts/Makefile.override
include ${ROOT_DIR}/_scripts/Makefile.open
include ${ROOT_DIR}/_scripts/Makefile.reconfigure
include ${ROOT_DIR}/_scripts/Makefile.readme

include ${ROOT_DIR}/_scripts/Makefile.status
include ${ROOT_DIR}/_scripts/Makefile.config
include ${ROOT_DIR}/_scripts/Makefile.ps
include ${ROOT_DIR}/_scripts/Makefile.logs

include ${ROOT_DIR}/.env_$(shell ${BIN}/docker_context)

include ${ROOT_DIR}/_scripts/Makefile.instance

TTY ?= 1
tty ?= ${TTY}

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} NIX_INSTANCE=${INSTANCE}
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_GENERIC_PREFIX "Enter the generic hostname prefix (not the instance name, but it goes before it)" nix
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_GIT_USERNAME "Enter your git name (username or full name)" "$$(git config --global --get user.name)"
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_GIT_EMAIL "Enter your git email address" "$$(git config --global --get user.email)"
	@ALLOW_BLANK=0 ${BIN}/reconfigure_ask ${ENV_FILE} NIX_DOCKER_SSH_HOST "Enter the Docker SSH host that this container will manage (eg. docker.example.com)"
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_DOCKER_SSH_USER "Enter the Docker SSH username" root
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_DOCKER_SSH_PORT "Enter the Docker SSH port" 22

.PHONY: config-if-neccessary
config-if-neccessary:
	@test -f ${ENV_FILE} || make --no-print-directory config ENV_FILE="${ENV_FILE}" instance="${instance}" tty="${tty}"

.PHONY: build # build and retag the base+common+user images
build: build-base build-user

.PHONY: build-base # build and retag the base+common images
build-base:
	@docker compose --env-file ${ENV_FILE} build nix-base
	@docker compose --env-file ${ENV_FILE} build nix-common

.PHONY: build-user # build and retag the user image
build-user:
	@docker compose --env-file ${ENV_FILE} build nix-user

.PHONY: build-cached # build the base images only if the image tags do not already exist
build-cached:
	@NIX_BASE_IMAGE_TAG=$$(dotenv -f ${ENV_FILE} get NIX_BASE_IMAGE_TAG); (docker image inspect $${NIX_BASE_IMAGE_TAG} >/dev/null && echo "Found cached image: $${NIX_BASE_IMAGE_TAG}") || docker compose --env-file ${ENV_FILE} build nix-base
	@NIX_COMMON_IMAGE_TAG=$$(dotenv -f ${ENV_FILE} get NIX_COMMON_IMAGE_TAG); (docker image inspect $${NIX_COMMON_IMAGE_TAG} >/dev/null && echo "Found cached image: $${NIX_COMMON_IMAGE_TAG}") || docker compose --env-file ${ENV_FILE} build nix-common

.PHONY: push # push the tagged nix-base and nix-common images to the Docker registry
push:
	docker push $$(dotenv -f ${ENV_FILE} get NIX_BASE_IMAGE_TAG)
	docker push $$(dotenv -f ${ENV_FILE} get NIX_COMMON_IMAGE_TAG)

.PHONY: pull # push the tagged nix-base and nix-common images to the Docker registry
pull:
	docker pull $$(dotenv -f ${ENV_FILE} get NIX_BASE_IMAGE_TAG)
	docker pull $$(dotenv -f ${ENV_FILE} get NIX_COMMON_IMAGE_TAG)

.PHONY: shell # Start a new shell container in the foreground
shell:
#### This must copy the env file to a temp file and set INSTANCE_SUFFIX as the hostname cannot be derrived from an env var passed on the command line?!
	@if [[ -f "${ENV_FILE}" ]]; then TEMPFILE=$$(mktemp /tmp/${PROJECT_NAME}.XXX.env); cp ${ENV_FILE} "$${TEMPFILE}"; ${BIN}/reconfigure "$${TEMPFILE}" "NIX_INSTANCE_SUFFIX=-${tty}"; NIX_GENERIC_PREFIX=$$(dotenv -f "$${TEMPFILE}" get NIX_GENERIC_PREFIX); (set -x; docker compose --env-file $${TEMPFILE} --project-name "${CWD_PROJECT_NAME}" run ${DAEMON_MODE_ARG} --name=$${NIX_GENERIC_PREFIX}-${INSTANCE}-${tty} --rm -it $${service:-nix-user} /bin/bash); rm -f $${TEMPFILE}; else echo "Env file is missing: ${ENV_FILE}"; echo -e "Try running: make config instance=${INSTANCE}\nOr: d.rymcg.tech shell config ${INSTANCE}"; fi

.PHONY: stop # Stop/remove the container
stop:
	@NIX_GENERIC_PREFIX=$$(dotenv -f "${ENV_FILE}" get NIX_GENERIC_PREFIX);	docker rm -f $${NIX_GENERIC_PREFIX}-${INSTANCE}-${tty}

.PHONY: start # Start a new shell container in the background
start:
	make --no-print-directory shell DAEMON_MODE_ARG=-d ENV_FILE=${ENV_FILE} instance=${instance} tty=${tty}

.PHONY: destroy # Deletes all containers AND the data volume for the given INSTANCE
destroy:
	@NIX_GENERIC_PREFIX=$$(dotenv -f "${ENV_FILE}" get NIX_GENERIC_PREFIX); ${BIN}/confirm no "Do you want to destroy all the containers AND volumes for the given context/instance (${DOCKER_CONTEXT}/${INSTANCE})" "?" && docker ps -q --filter="name=^$${NIX_GENERIC_PREFIX}-${INSTANCE}-" | xargs -iXX docker rm -f XX && docker volume rm -f nix_${INSTANCE}_home


.PHONY: attach # Attach to an existing shell container
attach: config-if-neccessary
	@CONTAINER_NAME="$$(dotenv -f "${ENV_FILE}" get NIX_GENERIC_PREFIX)-${INSTANCE}-${tty}"; if docker inspect "$${CONTAINER_NAME}" >/dev/null; then (set -x; docker attach "$${CONTAINER_NAME}"); else make --no-print-directory start ENV_FILE=${ENV_FILE} instance=${instance} tty=${tty} && docker attach "$${CONTAINER_NAME}"; fi || true

.PHONY: dev-sync
dev-sync:
	@${BIN}/dev-sync ${CWD_PROJECT_NAME}_home nix-user/nixpkgs .config/nixpkgs

.PHONY: install
install: build
	@echo "Build complete."
	@echo "No background services are required. You can now run \`make shell\` on demand."

.PHONY: volume-list
volume-list:
	@echo "## Found these volumes from various shell containers:"
	@docker volume ls -q --filter="name=^nix_.*_home"
	@echo ""
	@echo "## Use \`d.rymcg.tech shell destroy INSTANCE\`"
	@echo "## Or to manually delete them, use \`docker rm -f VOLUME\`"
