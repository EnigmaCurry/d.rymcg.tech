SHELL = /bin/bash
ROOT_DIR = ../
BIN = ../_scripts

include ${BIN}/Makefile.projects
include ${BIN}/Makefile.instance

.PHONY: config-hook # Configure the .env file
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} WORKSTATION_USER "Enter the virtual workstation username to create inside the container" $${USER}
	@${BIN}/reconfigure_ask ${ENV_FILE} WORKSTATION_PUBLIC_SSH_PORT "Enter the external (PUBLIC) SSH port mapped on the host"
	@${BIN}/reconfigure ${ENV_FILE} WORKSTATION_INSTANCE=${INSTANCE} WORKSTATION_DOCKER_CONTEXT=${DOCKER_CONTEXT}

.PHONY: override-hook
override-hook:
#### This sets the override template variables for docker-compose.instance.yaml:
#### The template dynamically renders to docker-compose.override_{DOCKER_CONTEXT}_{INSTANCE}.yaml
#### These settings are used to automatically generate the service container labels, and traefik config, inside the template.
#### The variable arguments have three forms: `=` `=:` `=@`
####   name=VARIABLE_NAME    # sets the template 'name' field to the value of VARIABLE_NAME found in the .env file
####                         # (this hardcodes the value into docker-compose.override.yaml)
####   name=:VARIABLE_NAME   # sets the template 'name' field to the literal string 'VARIABLE_NAME'
####                         # (this hardcodes the string into docker-compose.override.yaml)
####   name=@VARIABLE_NAME   # sets the template 'name' field to the literal string '${VARIABLE_NAME}'
####                         # (used for regular docker-compose expansion of env vars by name.)
	@${BIN}/docker_compose_override ${ENV_FILE} project=:workstation instance=@WORKSTATION_INSTANCE enable_docker_socket=WORKSTATION_ENABLE_DOCKER_SOCKET git_volume=WORKSTATION_GIT_VOLUME workstation_user=@WORKSTATION_USER ssh_port=@WORKSTATION_SSH_PORT

.PHONY: shell # Enter the virtual workstation shell
shell:
# Use setpriv to login so we set all the groups correctly:
# (This won't be required when logging in via SSH)
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -it -u root -e HOME=/home/$$(${BIN}/dotenv -f ${ENV_FILE} get WORKSTATION_USER) -e USER=$$(${BIN}/dotenv -f ${ENV_FILE} get WORKSTATION_USER) -e NO_INSTALL=true -w /home/$$(${BIN}/dotenv -f ${ENV_FILE} get WORKSTATION_USER) workstation setpriv --reuid=$$(${BIN}/dotenv -f ${ENV_FILE} get WORKSTATION_UID) --regid=$$(${BIN}/dotenv -f ${ENV_FILE} get WORKSTATION_GID) --init-groups /bin/bash"

