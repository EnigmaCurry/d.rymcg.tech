SHELL = /bin/bash
BIN = ../../_scripts

ENV_FILE = .env

.PHONY: help # Show this help screen
help:
	@grep -h '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/make \1 \t- \2/' | expand -t20

.PHONY: config # Configure the .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} PODMAN_USER "Enter the name of the (new) user account to run podman" $${USER}-podman
	@id $$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_USER) >/dev/null 2>&1 || (${BIN}/confirm yes "Do you want to create the user account now? (requires sudo)" " " && make --no-print-directory create-user) || true
	@${BIN}/reconfigure ${ENV_FILE} PODMAN_WORKSTATION_INSTANCE=$${INSTANCE:-default}
	@${BIN}/confirm $$(test -z "$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_SYSTEMD_WANTED_BY)" && echo no || echo yes) "Do you want to automatically start the podman workstation on system boot" "?" && ${BIN}/reconfigure ${ENV_FILE} PODMAN_WORKSTATION_SYSTEMD_WANTED_BY=default.target || ${BIN}/reconfigure ${ENV_FILE} PODMAN_WORKSTATION_SYSTEMD_WANTED_BY=

.PHONY: create-user # Create the system user account to run podman
create-user:
	@${BIN}/check_sudo
	@export CREATE_USER=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_USER) && export CREATE_USER_LINGER=$$(${BIN}/confirm yes "Do you want to enable systemd linger for the user? (This is required to start podman containers on system boot)" " " && echo true || echo false) && echo "Now going to create the user via sudo:" && sudo --preserve-env=CREATE_USER --preserve-env=CREATE_USER_LINGER /bin/bash ${BIN}/create_user && echo "User '$${CREATE_USER}' created."

.PHONY: build # Build the container image
build:
	@${BIN}/check_sudo
	@${BIN}/check_deps podman
	@PODMAN_USER=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_USER); PODMAN_WORKSTATION_IMAGE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_IMAGE); PODMAN_WORKSTATION_INSTANCE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_INSTANCE); TMP_DIR=$$(mktemp -d) && cp -a src "$${TMP_DIR}" && sudo chown -R "$${PODMAN_USER}" "$${TMP_DIR}" && cd / && sudo -u "$${PODMAN_USER}" podman build -t "$${PODMAN_WORKSTATION_IMAGE}-$${PODMAN_WORKSTATION_INSTANCE}" "$${TMP_DIR}/src"

.PHONY: install # Install the service
install:
	@${BIN}/check_sudo
	@${BIN}/check_deps envsubst
	@export PODMAN_USER=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_USER); export PODMAN_WORKSTATION_IMAGE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_IMAGE); export PODMAN_WORKSTATION_INSTANCE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_INSTANCE); export PODMAN_WORKSTATION_SYSTEMD_WANTED_BY=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_SYSTEMD_WANTED_BY); export XDG_RUNTIME_DIR=/run/user/$$(id -u $${PODMAN_USER}); TMP_DIR=$$(mktemp -d) && cp -a create_systemd_service.sh podman-systemd/* $${TMP_DIR} && sudo chown -R "$${PODMAN_USER}" "$${TMP_DIR}" && cd / && sudo -u "$${PODMAN_USER}" --preserve-env=PODMAN_USER --preserve-env=PODMAN_WORKSTATION_IMAGE --preserve-env=PODMAN_WORKSTATION_INSTANCE --preserve-env=PODMAN_WORKSTATION_SYSTEMD_WANTED_BY --preserve-env=XDG_RUNTIME_DIR /bin/bash $${TMP_DIR}/create_systemd_service.sh

.PHONY: uninstall # Stop and uninstall the service
uninstall: stop
	@${BIN}/check_sudo
	@export PODMAN_USER=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_USER); export PODMAN_WORKSTATION_IMAGE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_IMAGE); export PODMAN_WORKSTATION_INSTANCE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_INSTANCE); export XDG_RUNTIME_DIR=/run/user/$$(id -u $${PODMAN_USER}); cd / && sudo -u "$${PODMAN_USER}" --preserve-env=PODMAN_USER --preserve-env=PODMAN_WORKSTATION_IMAGE --preserve-env=PODMAN_WORKSTATION_INSTANCE --preserve-env=XDG_RUNTIME_DIR /bin/bash -c "set -x; systemctl --user stop $${PODMAN_WORKSTATION_IMAGE}-$${PODMAN_WORKSTATION_INSTANCE}.service && rm -f ~/.config/containers/systemd/$${PODMAN_WORKSTATION_IMAGE}-$${PODMAN_WORKSTATION_INSTANCE}.* && systemctl --user daemon-reload"

.PHONY: sudo # sudo into the podman user account system shell
sudo:
	@export PODMAN_USER=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_USER); export PODMAN_WORKSTATION_IMAGE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_IMAGE); export PODMAN_WORKSTATION_INSTANCE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_INSTANCE); export XDG_RUNTIME_DIR=/run/user/$$(id -u $${PODMAN_USER}); sudo -u $${PODMAN_USER} --preserve-env=PODMAN_USER --preserve-env=PODMAN_WORKSTATION_IMAGE --preserve-env=PODMAN_WORKSTATION_INSTANCE --preserve-env=XDG_RUNTIME_DIR -i /bin/bash -l

.PHONY: status # Show service status
status:
	@${BIN}/check_sudo
	@export PODMAN_USER=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_USER); export PODMAN_WORKSTATION_IMAGE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_IMAGE); export PODMAN_WORKSTATION_INSTANCE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_INSTANCE); export XDG_RUNTIME_DIR=/run/user/$$(id -u $${PODMAN_USER}); cd / && sudo -u "$${PODMAN_USER}" --preserve-env=PODMAN_USER --preserve-env=PODMAN_WORKSTATION_IMAGE --preserve-env=PODMAN_WORKSTATION_INSTANCE --preserve-env=XDG_RUNTIME_DIR /bin/bash -c "set -x; systemctl --user status $${PODMAN_WORKSTATION_IMAGE}-$${PODMAN_WORKSTATION_INSTANCE}.service"

.PHONY: start # Start service
start:
	@${BIN}/check_sudo
	@export PODMAN_USER=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_USER); export PODMAN_WORKSTATION_IMAGE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_IMAGE); export PODMAN_WORKSTATION_INSTANCE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_INSTANCE); export XDG_RUNTIME_DIR=/run/user/$$(id -u $${PODMAN_USER}); cd / && sudo -u "$${PODMAN_USER}" --preserve-env=PODMAN_USER --preserve-env=PODMAN_WORKSTATION_IMAGE --preserve-env=PODMAN_WORKSTATION_INSTANCE --preserve-env=XDG_RUNTIME_DIR /bin/bash -c "set -x; systemctl --user start $${PODMAN_WORKSTATION_IMAGE}-$${PODMAN_WORKSTATION_INSTANCE}.service && systemctl --user status --no-pager $${PODMAN_WORKSTATION_IMAGE}-$${PODMAN_WORKSTATION_INSTANCE}.service"

.PHONY: stop # Stop service
stop:
	@${BIN}/check_sudo
	@export PODMAN_USER=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_USER); export PODMAN_WORKSTATION_IMAGE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_IMAGE); export PODMAN_WORKSTATION_INSTANCE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_INSTANCE); export XDG_RUNTIME_DIR=/run/user/$$(id -u $${PODMAN_USER}); cd / && sudo -u "$${PODMAN_USER}" --preserve-env=PODMAN_USER --preserve-env=PODMAN_WORKSTATION_IMAGE --preserve-env=PODMAN_WORKSTATION_INSTANCE --preserve-env=XDG_RUNTIME_DIR /bin/bash -c "set -x; systemctl --user stop $${PODMAN_WORKSTATION_IMAGE}-$${PODMAN_WORKSTATION_INSTANCE}.service && systemctl --user status --no-pager $${PODMAN_WORKSTATION_IMAGE}-$${PODMAN_WORKSTATION_INSTANCE}.service"

.PHONY: destroy # Destroy service
destroy: uninstall
	@${BIN}/check_sudo
	@export PODMAN_USER=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_USER); export PODMAN_WORKSTATION_IMAGE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_IMAGE); export PODMAN_WORKSTATION_INSTANCE=$$(${BIN}/dotenv -f ${ENV_FILE} get PODMAN_WORKSTATION_INSTANCE); export XDG_RUNTIME_DIR=/run/user/$$(id -u $${PODMAN_USER}); cd / && sudo -u "$${PODMAN_USER}" --preserve-env=PODMAN_USER --preserve-env=PODMAN_WORKSTATION_IMAGE --preserve-env=PODMAN_WORKSTATION_INSTANCE --preserve-env=XDG_RUNTIME_DIR /bin/bash -c "set -x; podman volume rm -f $${PODMAN_WORKSTATION_IMAGE}-$${PODMAN_WORKSTATION_INSTANCE}"

