ROOT_DIR = ../..
include ${ROOT_DIR}/_scripts/Makefile.help
include ${ROOT_DIR}/_scripts/Makefile.globals
include ${ROOT_DIR}/_scripts/Makefile.docker-compose
include ${ROOT_DIR}/_scripts/Makefile.lifecycle
include ${ROOT_DIR}/_scripts/Makefile.clean
include ${ROOT_DIR}/_scripts/Makefile.override
include ${ROOT_DIR}/_scripts/Makefile.open
include ${ROOT_DIR}/_scripts/Makefile.reconfigure
include ${ROOT_DIR}/_scripts/Makefile.readme
include ${ROOT_DIR}/.env_$(shell ${BIN}/docker_context)



include ${ROOT_DIR}/_scripts/Makefile.instance

NAME ?= 1
name ?= ${NAME}

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

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} NIX_INSTANCE=$${INSTANCE:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_GIT_USERNAME "Enter your git name (username or full name)" "$$(git config --global --get user.name)"
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_GIT_EMAIL "Enter your git email address" "$$(git config --global --get user.email)"
	@ALLOW_BLANK=0 ${BIN}/reconfigure_ask ${ENV_FILE} NIX_DOCKER_SSH_HOST "Enter the Docker SSH host that this container will manage"
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_DOCKER_SSH_USER "Enter the Docker SSH username" root
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_DOCKER_SSH_PORT "Enter the Docker SSH port" 22

.PHONY: shell
shell:
	@docker compose --env-file ${ENV_FILE} --project-name "${CWD_PROJECT_NAME}" run -e INSTANCE_SUB_NAME=${name} --name=nix-${INSTANCE}-${name} --rm -it $${service:-nix-user} /bin/bash

.PHONY: dev-sync
dev-sync:
	@${BIN}/dev-sync ${CWD_PROJECT_NAME}_home nix-user/nixpkgs .config/nixpkgs

.PHONY: install
install: build
	@echo "Build complete."
	@echo "No background services are required. You can now run \`make shell\` on demand."
