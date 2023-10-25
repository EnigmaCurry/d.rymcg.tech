ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} REPOSITORY "Enter the github repository URL"
	@${BIN}/reconfigure_ask ${ENV_FILE} RUNNER_TOKEN "Enter the GitHub runner token"
