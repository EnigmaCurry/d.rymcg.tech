ROOT_DIR = ..
include ../_scripts/Makefile.projects-custom-build-custom-install

.PHONY: config-hook # Configure .env file
config-hook:
	@test -f ${ENV_FILE} || (cp .env-dist ${ENV_FILE} && echo "Created ${ENV_FILE}")
	@echo "TODO: please just edit ${ENV_FILE} manually."

.PHONY: build # Build container images
build:
	@make --no-print-directory docker-compose-build

.PHONY: install # (re)builds images and (re)starts services (only if changed)
install: build host-keys start

.PHONY: host-keys # Make SSH Host keys
host-keys: build
	docker build -t debian-bullseye-ssh-root -f Dockerfile.root .
	@VOLUME="${PROJECT_NAME}_ssh-keys"; SFTP_SSHD_UID="$$(${BIN}/dotenv -f ${ENV_FILE} get SFTP_SSHD_UID)"; ssh-key-chown(){ KEY="/keys/ssh_host_$${KEY_TYPE}_key"; echo "VOLUME=$${VOLUME}"; docker run --user 0:0 --cap-add LINUX_IMMUTABLE --rm -v $${VOLUME}:/keys debian-bullseye-ssh-root sh -c "test ! -f /keys/ssh_host_$${KEY_TYPE}_key && ssh-keygen -q -N '' -t $${KEY_TYPE} -f $${KEY} && echo '$${KEY_TYPE} key created' || echo '$${KEY_TYPE} key already exists.' && set -x && chattr -i $${KEY}* && ssh-keygen -l -f $${KEY} && chown $${SFTP_SSHD_UID} $${KEY}* && chattr +i $${KEY}* && ls -l $${KEY} && lsattr $${KEY}"; }; KEY_TYPE=rsa ssh-key-chown; KEY_TYPE=ed25519 ssh-key-chown

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -it sftp /bin/bash"
