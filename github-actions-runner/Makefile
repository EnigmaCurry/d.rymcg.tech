ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask RUNNER_NAME "Enter a name for this runner (hostname)" docker-test
	@${BIN}/reconfigure_ask REPOSITORY "Enter the github repository URL"
	@${BIN}/reconfigure_ask RUNNER_TOKEN "Enter the GitHub runner token"

