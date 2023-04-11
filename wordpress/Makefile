# Update this to point to your d.ry repo
ROOT_DIR = ${HOME}/git/d.rymcg.tech
include ${ROOT_DIR}/_scripts/Makefile.projects-external
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} WP_INSTANCE=${instance}
	@${BIN}/reconfigure_ask ${ENV_FILE} WP_TRAEFIK_HOST "Enter the wp domain name" ${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_password ${ENV_FILE} WP_DB_ROOT_PASSWORD
	@${BIN}/reconfigure_password ${ENV_FILE} WP_DB_PASSWORD

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:wp instance=@WP_INSTANCE traefik_host=@WP_TRAEFIK_HOST http_auth=WP_HTTP_AUTH http_auth_var=@WP_HTTP_AUTH ip_sourcerange=@WP_IP_SOURCERANGE
