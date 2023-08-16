SHELL = /bin/bash
ROOT_DIR = ../
BIN = ../_scripts

include ${BIN}/Makefile.projects

.PHONY: config-hook # Configure the .env file
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} WORKSTATION_USER "Enter the virtual workstation username to create inside the container" $${USER}

.PHONY: shell # Enter the virtual workstation shell
shell:
	@docker compose --env-file ${ENV_FILE} exec -it $${service:-virtual-workstation} /bin/bash
