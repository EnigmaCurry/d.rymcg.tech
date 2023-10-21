ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} LARYNX_TRAEFIK_HOST "Enter the gitea domain name" larynx-${INSTANCE}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_auth ${ENV_FILE} LARYNX

.PHONY: shell
shell:
	@docker-compose --env-file ${ENV_FILE} exec -it $${service:-app} /bin/sh -c "/bin/bash || /bin/sh"


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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:larynx instance=@LARYNX_INSTANCE traefik_host=@LARYNX_TRAEFIK_HOST http_auth=LARYNX_HTTP_AUTH http_auth_var=@LARYNX_HTTP_AUTH ip_sourcerange=@LARYNX_IP_SOURCERANGE oauth2=LARYNX_OAUTH2 authorized_group=LARYNX_OAUTH2_AUTHORIZED_GROUP
