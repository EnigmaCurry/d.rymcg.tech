ROOT_DIR = ../..
include ${ROOT_DIR}/_scripts/Makefile.projects-custom-build-custom-install
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: build # build and retag the base images
build:
	@docker compose --env-file ${ENV_FILE} build nix-base
	@docker compose --env-file ${ENV_FILE} build nix-common

.PHONY: build-cached # build the base images only if the image tags do not already exist
build-cached:
	@NIX_BASE_IMAGE_TAG=$$(dotenv -f ${ENV_FILE} get NIX_BASE_IMAGE_TAG); (docker image inspect $${NIX_BASE_IMAGE_TAG} >/dev/null && echo "Found cached image: $${NIX_BASE_IMAGE_TAG}") || docker compose --env-file ${ENV_FILE} build nix-base
	@NIX_COMMON_IMAGE_TAG=$$(dotenv -f ${ENV_FILE} get NIX_COMMON_IMAGE_TAG); (docker image inspect $${NIX_COMMON_IMAGE_TAG} >/dev/null && echo "Found cached image: $${NIX_COMMON_IMAGE_TAG}") || docker compose --env-file ${ENV_FILE} build nix-common

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} NIX_INSTANCE=$${INSTANCE:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_GIT_USERNAME "Enter your git username" "$$(git config --global --get user.name)"
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_GIT_EMAIL "Enter your git email address" "$$(git config --global --get user.email)"
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_DOCKER_SSH_HOST "Enter the Docker SSH host that this container will manage"
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_DOCKER_SSH_USER "Enter the Docker SSH username" root
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_DOCKER_SSH_PORT "Enter the Docker SSH port" 22

.PHONY: shell
shell:
	@docker compose --env-file ${ENV_FILE} --project-name "${CWD_PROJECT_NAME}" run --name "nix-${INSTANCE}-$${NAME:-1}" --rm -it $${service:-nix-user} /bin/bash

.PHONY: dev-sync
dev-sync:
	@${BIN}/dev-sync ${CWD_PROJECT_NAME}_home nix-user/nixpkgs .config/nixpkgs

.PHONY: install
install: build
	@echo "Build complete."
	@echo "No background services are required. You can now run \`make shell\` on demand."
