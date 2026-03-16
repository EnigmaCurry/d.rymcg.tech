ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} REPOSITORY "Enter the gitea repository URL"
	@${BIN}/reconfigure_ask ${ENV_FILE} RUNNER_TOKEN "Enter the Gitea runner token"

.PHONY: shell
shell:
	@container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'docker' 'runner' --default 'docker'") && make --no-print-directory docker-compose-shell SERVICE=$${container}
