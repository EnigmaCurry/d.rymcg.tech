ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} PODFETCH_TRAEFIK_HOST "Enter the Podfetch domain name" podfetch${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} PODFETCH_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} PODFETCH_HTTP_AUTH default=no
	@${BIN}/reconfigure_password ${ENV_FILE} PODFETCH_POSTGRES_PW 32

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:podfetch instance=@PODFETCH_INSTANCE traefik_host=@PODFETCH_TRAEFIK_HOST http_auth=PODFETCH_HTTP_AUTH http_auth_var=@PODFETCH_HTTP_AUTH ip_sourcerange=@PODFETCH_IP_SOURCERANGE

#### need to flesh this out - want to add a way to manage podfetch users via make 
.PHONY: users
users:
	@docker compose --env-file ${ENV_FILE} exec -it $${service:-proxy} /app/podfetch users"

#### need to flesh this out - want to add a way to manage podfetch podcasts via make 
.PHONY: podcasts
podcasts:
	@docker compose --env-file ${ENV_FILE} exec -it $${service:-proxy} /app/podfetch podcasts"
