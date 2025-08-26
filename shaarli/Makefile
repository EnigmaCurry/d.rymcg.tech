ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} SHAARLI_TRAEFIK_HOST "Enter the shaarli domain name" shaarli${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_auth ${ENV_FILE} SHAARLI

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:shaarli instance=@SHAARLI_INSTANCE traefik_host=@SHAARLI_TRAEFIK_HOST http_auth=SHAARLI_HTTP_AUTH http_auth_var=@SHAARLI_HTTP_AUTH ip_sourcerange=@SHAARLI_IP_SOURCERANGE oauth2=SHAARLI_OAUTH2 authorized_group=SHAARLI_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=SHAARLI_MTLS_AUTH mtls_authorized_certs=SHAARLI_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=shaarli

.PHONY: install-hook
install-hook:
	@echo
