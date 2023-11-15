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
	@echo ""
	@${BIN}/reconfigure ${ENV_FILE} PODFETCH_INSTANCE=$${instance:-default}
	@echo ""
	@(${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get PODFETCH_GPODDER_INTEGRATION_ENABLED)" == "true" && echo yes || echo no) "Do you want to enable the GPodder API" "?" && ${BIN}/reconfigure ${ENV_FILE} PODFETCH_GPODDER_INTEGRATION_ENABLED=true) || ${BIN}/reconfigure ${ENV_FILE} PODFETCH_GPODDER_INTEGRATION_ENABLED=false
	@echo
	@echo "You can configure HTTP Authentication through Traefik, Podfetch's internal Basic Authentication, or neither - but not both."
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} PODFETCH_HTTP_AUTH default=no
	@echo ""
	@test -n "$$(${BIN}/dotenv -f ${ENV_FILE} get PODFETCH_HTTP_AUTH)" && ${BIN}/reconfigure ${ENV_FILE} PODFETCH_BASIC_AUTH=false || (${BIN}/confirm yes "Enable Podfetch's Basic Authentication" "?" && ${BIN}/reconfigure ${ENV_FILE} PODFETCH_BASIC_AUTH=true && ${BIN}/reconfigure_ask ${ENV_FILE} PODFETCH_USERNAME "Enter your username" "-" && ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} PODFETCH_PASSWORD "Enter your password (leave blank to generate a random password)" "-" && (test -z "$$(${BIN}/dotenv -f ${ENV_FILE} get PODFETCH_PASSWORD)" && ${BIN}/reconfigure_password ${ENV_FILE} PODFETCH_PASSWORD 32 || true)) || ${BIN}/reconfigure ${ENV_FILE} PODFETCH_BASIC_AUTH=false
	@echo ""
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:podfetch instance=@PODFETCH_INSTANCE traefik_host=@PODFETCH_TRAEFIK_HOST http_auth=PODFETCH_HTTP_AUTH http_auth_var=@PODFETCH_HTTP_AUTH ip_sourcerange=@PODFETCH_IP_SOURCERANGE podfetch_basic_auth=PODFETCH_BASIC_AUTH podfetch_basic_auth_var=@PODFETCH_BASIC_AUTH podfetch_username=@PODFETCH_USERNAME podfetch_password=@PODFETCH_PASSWORD

#### need to flesh this out - want to add a way to manage podfetch users via `make` 
.PHONY: users
users:
	@docker compose --env-file ${ENV_FILE} exec -it $${service:-proxy} /app/podfetch users"

#### need to flesh this out - want to add a way to manage podfetch podcasts via `make` 
.PHONY: podcasts
podcasts:
	@docker compose --env-file ${ENV_FILE} exec -it $${service:-proxy} /app/podfetch podcasts"
