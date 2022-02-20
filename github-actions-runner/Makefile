ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} RUNNER_NAME "Enter a name for this runner (hostname)" docker-test
	@${BIN}/reconfigure_ask ${ENV_FILE} REPOSITORY "Enter the github repository URL"
	@${BIN}/reconfigure_ask ${ENV_FILE} RUNNER_TOKEN "Enter the GitHub runner token"

