ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} DOH_TRAEFIK_HOST "Enter the doh-server domain name" dns${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} DOH_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} DOH_PUBLIC_IP_ADDRESS "Enter the public IP address of the DNS service (enter the public HOST address; try 'curl ifconfig.me')"
	@${BIN}/reconfigure_ask ${ENV_FILE} DOH_UPSTREAM_DNS "Enter the upstream IP address of the DNS provider" 9.9.9.9
	@${BIN}/reconfigure_ask ${ENV_FILE} DOH_UPSTREAM_DNS_PORT "Enter the upstream port number of the DNS provider" 53
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:doh-server instance=@DOH_INSTANCE traefik_host=@DOH_TRAEFIK_HOST ip_sourcerange=@DOH_IP_SOURCERANGE traefik_entrypoint=DOH_TRAEFIK_ENTRYPOINT


.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=doh-server COMMAND=/bin/bash

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
