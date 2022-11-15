ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook # Configure .env file
config-hook:
	@test -f ${ENV_FILE} || (cp .env-dist ${ENV_FILE} && echo "Created ${ENV_FILE}")
	@echo "TODO: please just edit ${ENV_FILE} manually."

.PHONY: build-hook-post
build-hook-post:
	@make --no-print-directory sshd_config

.PHONY: sshd_config # Configure SSH keys and configuration
sshd_config:
	@set -eo pipefail; VOLUME="${PROJECT_NAME}_ssh-config"; SFTP_SSHD_UID="$$(${BIN}/dotenv -f ${ENV_FILE} get SFTP_SSHD_UID)"; DOCKER_COMMAND="docker compose --env-file=${ENV_FILE} --project-name=${PROJECT_NAME} run --rm config"; ensure-ssh-key(){ KEY="/home/sshd-user/ssh/keys/ssh_host_$${KEY_TYPE}_key"; echo "VOLUME=$${VOLUME}"; set -x; $${DOCKER_COMMAND} sh -c "mkdir -p /home/sshd-user/ssh/keys; test -f $${KEY} && echo '$${KEY_TYPE} key already exists.' || (ssh-keygen -q -N '' -t $${KEY_TYPE} -f $${KEY} && chattr -i $${KEY} $${KEY}.pub && chown $${SFTP_SSHD_UID} $${KEY}* && chattr +i $${KEY} $${KEY}.pub && echo '$${KEY_TYPE} key created') && ssh-keygen -l -f $${KEY} && ls -l $${KEY} && lsattr $${KEY}"; }; KEY_TYPE=rsa ensure-ssh-key; KEY_TYPE=ed25519 ensure-ssh-key; $${DOCKER_COMMAND} sh -c "chown sshd-user:sshd-user /home/sshd-user/ssh/ && chattr +i /home/sshd-user/ssh/sshd_config"; echo sshd_config done

.PHONY: unlock-mutable-config
unlock-mutable-config:
	@echo unlock-mutable-config
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="run --rm config sh -c 'find /home/sshd-user/ssh -type f | xargs chattr -i'"

.PHONY: destroy-hook-pre
destroy-hook-pre: unlock-mutable-config

.PHONY: destroy-hook-post
destroy-hook-post: 
	@docker volume rm -f ${PROJECT_NAME}_ssh-config
	@docker volume rm -f ${PROJECT_NAME}_sftp-data

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -it sftp /bin/bash"
