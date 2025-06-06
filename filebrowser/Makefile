ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} FILEBROWSER_TRAEFIK_HOST "Enter the filebrowser domain name" filebrowser${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} FILEBROWSER_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} FILEBROWSER
	@${BIN}/reconfigure_ask ${ENV_FILE} FILEBROWSER_ADMIN_USERNAME "Enter the filebrowser Admin user name or OAuth2 email address" admin
	@ROOT_DIR=${ROOT_DIR} ENV_FILE=${ENV_FILE} /bin/bash ./setup_auth.sh
	@${BIN}/reconfigure_password ${ENV_FILE} FILEBROWSER_ADMIN_PASSWORD 45
	@VOLUME_TYPE=$$(eval "${BIN}/script-wizard choose 'Choose the volume type' 'internal' 'external' --default $$(test -z $$(${BIN}/dotenv -f ${ENV_FILE} get FILEBROWSER_EXTERNAL_VOLUME) && echo 'internal' || echo 'external')"); test "$${VOLUME_TYPE}" == "external" && ${BIN}/reconfigure_volume ${ENV_FILE} FILEBROWSER_EXTERNAL_VOLUME || ${BIN}/reconfigure ${ENV_FILE} FILEBROWSER_EXTERNAL_VOLUME=
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:filebrowser instance=@FILEBROWSER_INSTANCE traefik_host=@FILEBROWSER_TRAEFIK_HOST http_auth=FILEBROWSER_HTTP_AUTH http_auth_var=@FILEBROWSER_HTTP_AUTH ip_sourcerange=@FILEBROWSER_IP_SOURCERANGE oauth2=FILEBROWSER_OAUTH2 authorized_group=FILEBROWSER_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=FILEBROWSER_MTLS_AUTH mtls_authorized_certs=FILEBROWSER_MTLS_AUTHORIZED_CERTS external_volume=FILEBROWSER_EXTERNAL_VOLUME

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=filebrowser

