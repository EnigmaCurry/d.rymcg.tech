ROOT_DIR = ../..
include ${ROOT_DIR}/_scripts/Makefile.projects-custom-install
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} NIX_INSTANCE=$${INSTANCE:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_DOCKER_SSH_HOST "Enter the Docker SSH host that this container will manage"
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_DOCKER_SSH_USER "Enter the Docker SSH username" root
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_DOCKER_SSH_PORT "Enter the Docker SSH port" 22

.PHONY: shell
shell:
	@docker compose --env-file ${ENV_FILE} --project-name "${CWD_PROJECT_NAME}" run --rm -it $${service:-nix-user} /bin/bash

.PHONY: dev-sync
dev-sync:
	@${BIN}/dev-sync ${CWD_PROJECT_NAME}_home nix-user/nixpkgs .config/nixpkgs

.PHONY: install
install: build
	@echo "Build complete."
	@echo "No background services are required. You can now run \`make shell\` on demand."
