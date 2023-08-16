SHELL = /bin/bash
ROOT_DIR = ../
BIN = ../_scripts

include ${BIN}/Makefile.projects
include ${BIN}/Makefile.instance

.PHONY: config-hook # Configure the .env file
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} WORKSTATION_USER "Enter the virtual workstation username to create inside the container" $${USER}
	@${BIN}/reconfigure_ask ${ENV_FILE} WORKSTATION_PUBLIC_SSH_PORT "Enter the external (PUBLIC) SSH port mapped on the host"

.PHONY: shell # Enter the virtual workstation shell
shell:
# Use setpriv to login so we set all the groups correctly:
# (This won't be required when logging in via SSH)
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -it -u root -e HOME=/home/$$(${BIN}/dotenv -f ${ENV_FILE} get WORKSTATION_USER) -e USER=$$(${BIN}/dotenv -f ${ENV_FILE} get WORKSTATION_USER) -w /home/$$(${BIN}/dotenv -f ${ENV_FILE} get WORKSTATION_USER) workstation setpriv --reuid=$$(${BIN}/dotenv -f ${ENV_FILE} get WORKSTATION_UID) --regid=$$(${BIN}/dotenv -f ${ENV_FILE} get WORKSTATION_GID) --init-groups /bin/bash"
