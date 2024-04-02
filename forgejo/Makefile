ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} FORGEJO_TRAEFIK_HOST "Enter your forgejo domain name" git${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} FORGEJO_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} APP_NAME "Enter the service description" "$${instance:-default} - git hosting"
	@PUBLIC_HTTPS_PORT="$$(${BIN}/dotenv -f ${ROOT_DIR}/${ROOT_ENV} get PUBLIC_HTTPS_PORT)"; test -n "$${PUBLIC_HTTPS_PORT}" && ${BIN}/reconfigure ${ENV_FILE} "FORGEJO__server__ROOT_URL=https://$$(${BIN}/dotenv -f ${ENV_FILE} get FORGEJO_TRAEFIK_HOST):$${PUBLIC_HTTPS_PORT}" || ${BIN}/reconfigure ${ENV_FILE} "FORGEJO__server__ROOT_URL=https://$$(${BIN}/dotenv -f ${ENV_FILE} get FORGEJO_TRAEFIK_HOST)"

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:forgejo instance=@FORGEJO_INSTANCE traefik_host=@FORGEJO_TRAEFIK_HOST ip_sourcerange=@FORGEJO_IP_SOURCERANGE forgejo_port=@FORGEJO_PORT
	
.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=forgejo
