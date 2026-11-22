ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} EJABBERD_HOST "Enter the xmpp domain name" xmpp${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	echo ${ROOT_ENV}
	@${BIN}/reconfigure ${ENV_FILE} CERTIFICATE_VOLUME=local_certificate-ca_$$(${BIN}/dotenv -f ${ENV_FILE} get EJABBERD_HOST)
	@make -C ${ROOT_DIR}/_terminal/certificate-ca build ca cert DOMAIN="$$(${BIN}/dotenv -f ${ENV_FILE} get EJABBERD_HOST)" CHANGE_UID=9000 CHANGE_GID=9000

.PHONY: register
register:
	@ENV_FILE="${ENV_FILE}" EJABBERD_HOST="$$(${BIN}/dotenv -f ${ENV_FILE} get EJABBERD_HOST)" ${BIN}/env_ask USERNAME="Enter the new username to create (dont enter the domain name)" ./helper.sh register

.PHONY: room
room:
	@ENV_FILE="${ENV_FILE}" EJABBERD_HOST="$$(${BIN}/dotenv -f ${ENV_FILE} get EJABBERD_HOST)" ${BIN}/env_ask ROOM="Enter the new room to create (dont enter the domain name)" ./helper.sh create_room

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=ejabberd

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
