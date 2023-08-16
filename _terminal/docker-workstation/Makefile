SHELL = /bin/bash
ROOT_DIR = ../../
BIN = ../../_scripts

include ${BIN}/Makefile.projects

ENV_FILE = .env

.PHONY: config-hook # Configure the .env file
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} VIRTUAL_WORKSTATION_USER "Enter the virtual workstation username to create inside the container" $${USER}

.PHONY: shell # Enter the virtual workstation shell
shell:
<<<<<<< Updated upstream
	@${BIN}/check_sudo
	@export PODMAN_USER=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_USER); export PODMAN_WORKSTATION_IMAGE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_IMAGE); export PODMAN_WORKSTATION_INSTANCE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_INSTANCE); export XDG_RUNTIME_DIR=/run/user/$$(id -u $${PODMAN_USER}); cd / && sudo -u "$${PODMAN_USER}" --preserve-env=PODMAN_USER --preserve-env=PODMAN_WORKSTATION_IMAGE --preserve-env=PODMAN_WORKSTATION_INSTANCE --preserve-env=XDG_RUNTIME_DIR --preserve-env=PUBLIC_SSH_KEY podman exec -it systemd-$${PODMAN_WORKSTATION_IMAGE}-$${PODMAN_WORKSTATION_INSTANCE} /bin/bash -l

.PHONY: ssh-config # Add entry to your local SSH config for the workstation container shell
ssh-config:
	@export PODMAN_SSH_IP_ADDRESS=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_SSH_IP_ADDRESS); export PODMAN_SSH_PORT=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_SSH_PORT); export PODMAN_WORKSTATION_HOSTNAME=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_HOSTNAME); set -x; cat ssh-config.template | envsubst >> $${HOME}/.ssh/config

.PHONY: logs # Show container logs
logs:
	@${BIN}/check_sudo
	@export PODMAN_USER=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_USER); export PODMAN_WORKSTATION_IMAGE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_IMAGE); export PODMAN_WORKSTATION_INSTANCE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_INSTANCE); export XDG_RUNTIME_DIR=/run/user/$$(id -u $${PODMAN_USER}); cd / && sudo -u "$${PODMAN_USER}" --preserve-env=PODMAN_USER --preserve-env=PODMAN_WORKSTATION_IMAGE --preserve-env=PODMAN_WORKSTATION_INSTANCE --preserve-env=XDG_RUNTIME_DIR --preserve-env=PUBLIC_SSH_KEY journalctl --user --unit $${PODMAN_WORKSTATION_IMAGE}-$${PODMAN_WORKSTATION_INSTANCE}
=======
	@docker compose --env-file ${ENV_FILE} exec -it $${service:-virtual-workstation} /bin/bash
>>>>>>> Stashed changes
