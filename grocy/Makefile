## ROOT_DIR is the full path to the git clone of d.rymcg.tech:
ROOT_DIR = ${HOME}/git/vendor/enigmacurry/d.rymcg.tech
## This Makefile inherits abilities from d.rymcg.tech Makefiles
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

BASIC_OVERRIDES = project=:grocy context=:"${DOCKER_CONTEXT}" instance=GROCY_INSTANCE traefik_host=GROCY_TRAEFIK_HOST traefik_host_var=:GROCY_TRAEFIK_HOST http_auth=GROCY_HTTP_AUTH http_auth_var=:GROCY_HTTP_AUTH ip_sourcerange_var=:GROCY_IP_SOURCERANGE development_mode=GROCY_DEVELOPMENT_MODE

.PHONY: config-hook-basic-traefik
config-hook-basic-traefik:
### config-hook is for the custom configuration the user must enter when running `make config`:
### reconfigure_ask will ask the user to enter the value for a variable, with the given prompt, with the given default value, and save it to the env file:
### reconfigure will directly set a value in the env file:
	@${BIN}/reconfigure ${ENV_FILE} GROCY_INSTANCE=$${instance:-default}
### configure IP filter:
	@${BIN}/reconfigure_ask ${ENV_FILE} GROCY_IP_SOURCERANGE "Enter the client IP Address range filter (CIDR)" 0.0.0.0/0
### Configure HTTP Auth:
	@(${BIN}/confirm $$(test -n "$$(${BIN}/dotenv -f ${ENV_FILE} get GROCY_HTTP_AUTH)" && echo yes || echo no) "Do you want to enable HTTP Basic Authentication" "?" && ${BIN}/reconfigure_htpasswd ${ENV_FILE} GROCY_HTTP_AUTH) || ${BIN}/reconfigure ${ENV_FILE} GROCY_HTTP_AUTH=''

## Generic project Makefile header is included from ../_common/Makefile.generic

.PHONY: config-hook
config-hook:
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
	@${BIN}/reconfigure_ask ${ENV_FILE} GROCY_TRAEFIK_HOST "Enter the website domain name" grocy${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} GROCY_UID "Enter the UID the docker container should run as" "54321"
	@${BIN}/reconfigure_ask ${ENV_FILE} GROCY_GID "Enter the GID the docker container should run as" "54321"
	@${BIN}/reconfigure_ask ${ENV_FILE} GROCY_TZ "Enter the timezone" "US/Eastern"

.PHONY: override-hook
override-hook:
#### This sets the standard override variables for docker-compose.instance.yaml - add your own at the end:
	@${BIN}/docker_compose_override ${ENV_FILE} ${BASIC_OVERRIDES}

.PHONY: shell # Enter container shell
shell:
	@docker-compose --env-file ${ENV_FILE} exec $${service:-grocy} /bin/sh -c "/bin/bash || /bin/sh"