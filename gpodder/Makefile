ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/wizard BLAH ${ENV_FILE} GPODDER_TRAEFIK_HOST "Enter the gpodder domain name" gpodder${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} GPODDER_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} GPODDER
	@${BIN}/reconfigure_ask ${ENV_FILE} GPODDER_IP_SOURCERANGE "Enter the client IP Address range filter (CIDR)" 0.0.0.0/0
	@(${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get GPODDER_DEVELOPMENT_MODE)" == "true" && echo yes || echo no) "Do you want to enable live-reload development mode" "?" && ${BIN}/reconfigure ${ENV_FILE} GPODDER_DEVELOPMENT_MODE=true) || ${BIN}/reconfigure ${ENV_FILE} GPODDER_DEVELOPMENT_MODE=false
	@${BIN}/reconfigure_ask ${ENV_FILE} GPODDER_UID "Enter the UID the docker container should run as" "54321"
	@${BIN}/reconfigure_ask ${ENV_FILE} GPODDER_GID "Enter the GID the docker container should run as" "54321"
	@${BIN}/reconfigure_ask ${ENV_FILE} GPODDER_PW "Enter password for the gPodder GUI (optional)" 
	@${BIN}/reconfigure_ask ${ENV_FILE} GPODDER_TZ "Enter the timezone" "America/New_York"
	@${BIN}/reconfigure_ask ${ENV_FILE} GPODDER_PORT "Enter the port gPodder should use" "3000"
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:gpodder instance=@GPODDER_INSTANCE traefik_host=@GPODDER_TRAEFIK_HOST http_auth=GPODDER_HTTP_AUTH http_auth_var=@GPODDER_HTTP_AUTH ip_sourcerange=@GPODDER_IP_SOURCERANGE oauth2=GPODDER_OAUTH2 authorized_group=GPODDER_OAUTH2_AUTHORIZED_GROUP

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=gpodder
