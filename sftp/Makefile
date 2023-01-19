ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-custom-install

.PHONY: config-hook
config-hook:
	@test -f ${ENV_FILE} || (cp .env-dist ${ENV_FILE} && echo "Created ${ENV_FILE}")
	@${BIN}/reconfigure_ask ${ENV_FILE} SFTP_PORT "Enter the public SSH port"
	@${BIN}/reconfigure_ask ${ENV_FILE} SFTP_USERS "Enter the user:uid list"
	@${BIN}/reconfigure_ask ${ENV_FILE} SFTP_VOLUMES "Enter the volume:user:mount list (can be blank)"


.PHONY: install # (re)builds images and (re)starts services
install: uninstall build start
.PHONY: uninstall # Remove service containers, leaving the volumes intact
uninstall: down
.PHONY: reinstall # Remove service containers, and re-install (volumes left intact).
reinstall: uninstall install

.PHONY: override-hook
override-hook:
	@${BIN}/docker_compose_override ${ENV_FILE} SFTP_USERS SFTP_VOLUMES

.PHONY: build-hook-post
build-hook-post: sshd_config lock-immutable-config

.PHONY: sshd_config # Configure SSH keys and configuration
sshd_config: unlock-mutable-config
	@source ${BIN}/funcs.sh; export ENV_FILE="${ENV_FILE}"; cat sshd_config | docker_run -i --user root --entrypoint='' -v "${PROJECT_NAME}_ssh-config:/etc/ssh" sftp-sftp sh -c "cat > /etc/ssh/sshd_config"
	@set -eo pipefail; VOLUME="${PROJECT_NAME}_ssh-config"; DOCKER_COMMAND="docker compose --env-file=${ENV_FILE} --project-name=${PROJECT_NAME} run --rm config"; ensure-ssh-key(){ KEY="/etc/ssh/keys/ssh_host_$${KEY_TYPE}_key"; echo "VOLUME=$${VOLUME}"; set -x; $${DOCKER_COMMAND} sh -c "mkdir -p /etc/ssh/keys; test -f $${KEY} && echo '$${KEY_TYPE} key already exists.' || (ssh-keygen -q -N '' -t $${KEY_TYPE} -f $${KEY} && echo '$${KEY_TYPE} key created') && ssh-keygen -l -f $${KEY} && ls -l $${KEY} && lsattr $${KEY}"; }; KEY_TYPE=rsa ensure-ssh-key; KEY_TYPE=ed25519 ensure-ssh-key;
	@echo sshd_config done

.PHONY: unlock-mutable-config
unlock-mutable-config:
	@echo unlock-mutable-config
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="run --rm config sh -c 'find /etc/ssh -type f | grep -v sshd.pid | xargs chattr -i'"

.PHONY: lock-immutable-config
lock-immutable-config:
	@echo lock-immutable-config
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="run --rm config sh -c 'find /etc/ssh -type f | grep -v sshd.pid | xargs chattr +i'"


.PHONY: destroy-hook-pre
destroy-hook-pre: unlock-mutable-config

.PHONY: destroy-hook-post
destroy-hook-post:
	@docker volume rm -f ${PROJECT_NAME}_ssh-config
	@docker volume rm -f ${PROJECT_NAME}_sftp-data

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -it sftp /bin/bash"

.PHONY: ssh-copy-id
ssh-copy-id: unlock-mutable-config
	ssh-add -L
	@export ENV_FILE="${ENV_FILE}"; [[ -z "$${SSH_USER:-$${user}}" ]] && read -p "Which SSH username do you want authorize with your local keys? : " SSH_USER; AUTH_FILE="/etc/ssh/keys/$${SSH_USER:-${user}}_authorized_keys"; source ${BIN}/funcs.sh; ssh-add -L | docker_exec -i --user root $$(docker_compose ps -q sftp) sh -c "cat >> $${AUTH_FILE} && sort -u -o $${AUTH_FILE} $${AUTH_FILE} && chmod 0600 $${AUTH_FILE} && chown $${SSH_USER:-${user}}:$${SSH_USER:-${user}} $${AUTH_FILE}"
	@make --no-print-directory lock-immutable-config


.PHONY: ssh-clear-id
ssh-clear-id: unlock-mutable-config
	@export ENV_FILE="${ENV_FILE}"; [[ -z "$${SSH_USER:-$${user}}" ]] && read -p "Which SSH username do you want deauthorize from all keys? : " SSH_USER; AUTH_FILE="/etc/ssh/keys/$${SSH_USER:-${user}}_authorized_keys"; source ${BIN}/funcs.sh; ssh-add -L | docker_exec -i --user root $$(docker_compose ps -q sftp) sh -c "truncate -s 0 $${AUTH_FILE}"
	@make --no-print-directory lock-immutable-config


.PHONY: open
open:
	@SSH_USER=$$(${BIN}/dotenv -f ${ENV_FILE} get SFTP_USERS | cut -d ":" -f 1); sftp -P $$(${BIN}/dotenv -f ${ENV_FILE} get SFTP_PORT) $${SSH_USER}@ssh.${ROOT_DOMAIN}

.PHONY: sshfs
sshfs:
	@mkdir -p ${HOME}/mnt/sftp.${ROOT_DOMAIN}
	sshfs sftp.${ROOT_DOMAIN}: ${HOME}/mnt/sftp.${ROOT_DOMAIN}
