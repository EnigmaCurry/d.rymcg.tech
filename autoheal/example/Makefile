ROOT_DIR = ../..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} TIMEOUT "Set the timeout in seconds. (If < 30, service will be healthy, otherwise unhealthy)" 60
