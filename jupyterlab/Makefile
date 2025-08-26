ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} JUPYTERLAB_TRAEFIK_HOST "Enter the jupyterlab domain name" jupyterlab${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} JUPYTERLAB_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_password ${ENV_FILE} JUPYTERLAB_JUPYTER_TOKEN
	@${BIN}/reconfigure_auth ${ENV_FILE} JUPYTERLAB

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=jupyterlab

.PHONY: token
token:
	@echo $$(${BIN}/dotenv -f ${ENV_FILE} get JUPYTERLAB_JUPYTER_TOKEN)

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:jupyterlab instance=@JUPYTERLAB_INSTANCE traefik_host=@JUPYTERLAB_TRAEFIK_HOST http_auth=JUPYTERLAB_HTTP_AUTH http_auth_var=@JUPYTERLAB_HTTP_AUTH ip_sourcerange=@JUPYTERLAB_IP_SOURCERANGE oauth2=JUPYTERLAB_OAUTH2 authorized_group=JUPYTERLAB_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=JUPYTERLAB_MTLS_AUTH mtls_authorized_certs=JUPYTERLAB_MTLS_AUTHORIZED_CERTS

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
