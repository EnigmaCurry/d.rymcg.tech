ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-no-open
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure ${ENV_FILE} ARCH_XPRA_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} ARCH_XPRA_HOSTNAME "Enter the hostname for the instance" arch-xpra${INSTANCE_URL_SUFFIX}
	@${BIN}/reconfigure_ask ${ENV_FILE} ARCH_XPRA_USERNAME "Enter the SSH username to create"
	@${BIN}/reconfigure_ask ${ENV_FILE} ARCH_XPRA_AUTHORIZED_KEY "Enter the SSH authorized key (eg. copy from ~/.ssh/id_rsa.pub)"
	@echo ""

.PHONY: root-shell
root-shell:
	@make --no-print-directory docker-compose-shell SERVICE=arch-xpra

.PHONY: open
open:
	@TERM=xterm-256color HOST=$$(docker context inspect | jq -r '.[].Endpoints.docker.Host' | sed 's|ssh://||'); ssh -Y $${HOST} -p 2222 -l gary emacsclient -c

.PHONY: shell
shell:
	@TERM=xterm-256color HOST=$$(docker context inspect | jq -r '.[].Endpoints.docker.Host' | sed 's|ssh://||'); ssh -Y $${HOST} -p 2222 -l $$(${BIN}/dotenv -f ${ENV_FILE} get ARCH_XPRA_USERNAME)
