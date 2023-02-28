ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} THTTPD_TRAEFIK_HOST "Enter the website domain name" thttpd${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} THTTPD_INSTANCE=${instance}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} THTTPD_HTTP_AUTH default=no

.PHONY: shell
shell:
	docker compose --env-file=${ENV_FILE} exec -it thttpd /bin/sh

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:thttpd instance=@THTTPD_INSTANCE traefik_host=@THTTPD_TRAEFIK_HOST http_auth=THTTPD_HTTP_AUTH http_auth_var=@THTTPD_HTTP_AUTH ip_sourcerange=@THTTPD_IP_SOURCERANGE
