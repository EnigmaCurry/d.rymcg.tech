ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-no-open
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} MUMBLE_TRAEFIK_HOST "Enter the mumble domain name" mumble${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} MUMBLE_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_password ${ENV_FILE} MUMBLE_SUPERUSER_PASSWORD
	@echo ""

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:mumble instance=@MUMBLE_INSTANCE traefik_host=@MUMBLE_TRAEFIK_HOST ip_sourcerange=@MUMBLE_IP_SOURCERANGE


.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=mumble COMMAND=/bin/bash

.PHONY: open
open:
	@echo "##"
	@echo "## Download the mumble client from your package manager"
	@echo "## or from https://www.mumble.info/"
	@echo "##"
	@echo "## Use your mumble client to connect to your server:"
	@echo "##  address: $$(${BIN}/dotenv -f ${ENV_FILE} get MUMBLE_TRAEFIK_HOST)"
	@echo "##  port: $$(${BIN}/dotenv -f ../traefik/.env_${DOCKER_CONTEXT}_default get TRAEFIK_MUMBLE_ENTRYPOINT_PORT)"
	@echo "##  username: SuperUser"
	@echo "##  password: $$(${BIN}/dotenv -f ${ENV_FILE} get MUMBLE_SUPERUSER_PASSWORD)"
	@echo "##"
	@echo "## Open access and user registration is enabled by default!"
	@echo "## Use the SuperUser account to edit the global ACLs to change these defaults."
	@echo "##"

.PHONY: client
client:
	@./client.sh
