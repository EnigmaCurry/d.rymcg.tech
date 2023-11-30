ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-no-open
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure ${ENV_FILE} DOCKER_WORKSTATION_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} DOCKER_WORKSTATION_HOSTNAME "Enter the hostname for the instance" workstation${INSTANCE_URL_SUFFIX}
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} DOCKER_WORKSTATION_USERNAME "Enter the SSH username to create"
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} DOCKER_WORKSTATION_AUTHORIZED_KEY "Enter the SSH authorized key (eg. copy from ~/.ssh/id_rsa.pub)"
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} DOCKER_WORKSTATION_SSH_PORT "Enter the external SSH port to map on the Docker host network"
	@echo
	@${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_WORKSTATION_EMACS_BOOTSTRAP) == "true" ]] && echo "yes" || echo "no") "Do you want to bootstrap the Emacs environment" "?" && (${BIN}/reconfigure ${ENV_FILE} DOCKER_WORKSTATION_EMACS_BOOTSTRAP=true && echo && ${BIN}/reconfigure_ask ${ENV_FILE} DOCKER_WORKSTATION_EMACS_CONFIG_REPO "Enter the Emacs config git repository" && echo && ${BIN}/reconfigure_ask ${ENV_FILE} DOCKER_WORKSTATION_EMACS_CONFIG_BRANCH "Enter the git branch for your Emacs config") || ${BIN}/reconfigure ${ENV_FILE} DOCKER_WORKSTATION_EMACS_BOOTSTRAP=false || true
	@echo

.PHONY: root-shell
root-shell:
	@make --no-print-directory docker-compose-shell SERVICE=docker-workstation

.PHONY: shell
shell:
	@HOST=$$(docker context inspect | jq -r '.[].Endpoints.docker.Host' | sed 's|ssh://||'); ssh -Y $${HOST} -p 2222 -l $$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_WORKSTATION_USERNAME)
