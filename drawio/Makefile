ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} DRAWIO_INSTANCE=${instance}
	@${BIN}/reconfigure_ask ${ENV_FILE} DRAWIO_TRAEFIK_HOST "Enter the drawio domain name" diagram${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_auth ${ENV_FILE} DRAWIO
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:drawio instance=@DRAWIO_INSTANCE traefik_host=@DRAWIO_TRAEFIK_HOST http_auth=DRAWIO_HTTP_AUTH http_auth_var=@DRAWIO_HTTP_AUTH ip_sourcerange=@DRAWIO_IP_SOURCERANGE oauth2=DRAWIO_OAUTH2 authorized_group=DRAWIO_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=DRAWIO_MTLS_AUTH mtls_authorized_certs=DRAWIO_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'plantuml-server' 'image-export' 'drawio' --default 'drawio'") && make --no-print-directory docker-compose-shell SERVICE=$${container}
