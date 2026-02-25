ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} WOODPECKER_TRAEFIK_HOST "Enter the woodpecker server domain name" woodpecker${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} WOODPECKER_GRPC_HOST "Enter the woodpecker GRPC domain name" woodpecker-grpc${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_password ${ENV_FILE} WOODPECKER_AGENT_SECRET
	@${BIN}/reconfigure ${ENV_FILE} WOODPECKER_INSTANCE=$${instance:-default}
	@echo ""
	@${BIN}/reconfigure_compose_profiles_select ${ENV_FILE} server="Woodpecker Server" agent="Woodpecker Agent"

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:woodpecker instance=@WOODPECKER_INSTANCE traefik_host=@WOODPECKER_TRAEFIK_HOST grpc_host=@WOODPECKER_GRPC_HOST ip_sourcerange=@WOODPECKER_IP_SOURCERANGE

.PHONY: shell # Enter one of the container shells
shell:
	@container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'server' 'agent' --default 'server'") && make --no-print-directory docker-compose-shell SERVICE=$${container}
