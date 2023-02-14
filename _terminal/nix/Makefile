ROOT_DIR = ../..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} NIX_INSTANCE=$${INSTANCE:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_DOCKER_SSH_HOST "Enter the Docker SSH host that this container will manage"
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_DOCKER_SSH_USER "Enter the Docker SSH username" root
	@${BIN}/reconfigure_ask ${ENV_FILE} NIX_DOCKER_SSH_PORT "Enter the Docker SSH port" 22

.PHONY: shell
shell:
	@HAD_TO_WAIT=false; while docker compose --env-file ${ENV_FILE} --project-name "${CWD_PROJECT_NAME}" exec -it $${service:-nix-user} /bin/bash -c "test ! -f .bashrc"; do echo "Still waiting for \`home-manager switch\` to finish ..."; sleep 10; HAD_TO_WAIT=true; done; if [[ "$$HAD_TO_WAIT" == "true" ]]; then sleep 2; fi;
	@docker compose --env-file ${ENV_FILE} --project-name "${CWD_PROJECT_NAME}" exec -it $${service:-nix-user} /bin/bash
