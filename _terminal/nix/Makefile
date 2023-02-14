ROOT_DIR = ../..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} NIX_INSTANCE=$${INSTANCE:-default}

.PHONY: shell
shell:
	docker compose --env-file ${ENV_FILE} --project-name "${CWD_PROJECT_NAME}" exec -it $${service:-nix-user} /bin/bash
