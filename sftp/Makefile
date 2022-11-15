ROOT_DIR = ..
include ../_scripts/Makefile.projects-custom-install

.PHONY: config-hook # Configure .env file
config-hook:
	@test -f ${ENV_FILE} || (cp .env-dist ${ENV_FILE} && echo "Created ${ENV_FILE}")
	@${BIN}/reconfigure_ask ${ENV_FILE} SFTP_USERS "Enter the user:uid list"
	@echo "After you run \`make install\`, run \`make ssh-copy-id\`."

.PHONY: install # (re)builds images and (re)starts services
install: uninstall build start

.PHONY: build-hook-post
build-hook-post: sshd_config lock-immutable-config

.PHONY: sshd_config # Configure SSH keys and configuration
sshd_config: unlock-mutable-config
	@source ${BIN}/funcs.sh; cat sshd_config | docker_run -i --user root --entrypoint='' -v "${PROJECT_NAME}_ssh-config:/etc/ssh" sftp-sftp sh -c "cat > /etc/ssh/sshd_config"
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
	@read -p "Copy your local ssh-agent keys to which SSH username? : " SSH_USER; AUTH_FILE="/etc/ssh/keys/$${SSH_USER}_authorized_keys"; source ${BIN}/funcs.sh; ssh-add -L | docker_exec -i --user root $$(docker_compose ps -q sftp) sh -c "cat >> $${AUTH_FILE} && sort -u -o $${AUTH_FILE} $${AUTH_FILE} && chmod 0600 $${AUTH_FILE} && chown $${SSH_USER}:$${SSH_USER} $${AUTH_FILE}"
	@make --no-print-directory lock-immutable-config

.PHONY: ssh-clear-id
ssh-clear-id: unlock-mutable-config
	@read -p "Enter the SSH username to clear all ids for: " SSH_USER; AUTH_FILE="/etc/ssh/keys/$${SSH_USER}_authorized_keys"; source ${BIN}/funcs.sh; docker_run --user root --entrypoint="" -v "${PROJECT_NAME}_ssh-config:/etc/ssh" sftp-sftp sh -c "cat /dev/null > $${AUTH_FILE} && chmod 0600 $${AUTH_FILE}"
	@make --no-print-directory lock-immutable-config
