ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} PHOTOPRISM_TRAEFIK_HOST "Enter the photoprism domain name" photoprism${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} PHOTOPRISM_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} PHOTOPRISM_HTTP_AUTH default=no
	@${BIN}/reconfigure_oauth2 ${ENV_FILE} PHOTOPRISM_OAUTH2 default=$$( ${BIN}/dotenv -f ${ENV_FILE} get PHOTOPRISM_OAUTH2 )
	@echo ""
	@${BIN}/reconfigure_password ${ENV_FILE} PHOTOPRISM_DATABASE_PASSWORD 32

	@echo ""
	@${BIN}/reconfigure_ask ${ENV_FILE} PHOTOPRISM_ADMIN_USER "Enter the admin user name" ${PHOTOPRISM_ADMIN_USER}
	@echo ""
	@${BIN}/reconfigure_ask ${ENV_FILE} PHOTOPRISM_ORIGINALS_VOLUME "Enter the host volume where your media files will live" ${PHOTOPRISM_ORIGINALS_VOLUME}
	@echo ""
	@${BIN}/reconfigure_ask ${ENV_FILE} PHOTOPRISM_SITE_CAPTION "Enter the site caption" ${PHOTOPRISM_SITE_CAPTION}
	@echo ""
	@${BIN}/reconfigure_ask ${ENV_FILE} PHOTOPRISM_SITE_DESCRIPTION "Enter the site description" ${PHOTOPRISM_SITE_DESCRIPTION}
	@echo ""
	@${BIN}/reconfigure_ask ${ENV_FILE} PHOTOPRISM_SITE_AUTHOR "Enter the site author" ${PHOTOPRISM_SITE_AUTHOR}
	@echo ""
	@echo "There are other Photoprism options you can configure by manually editing your \`${ENV_FILE}\` file."
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:photoprism instance=@PHOTOPRISM_INSTANCE traefik_host=@PHOTOPRISM_TRAEFIK_HOST http_auth=PHOTOPRISM_HTTP_AUTH http_auth_var=@PHOTOPRISM_HTTP_AUTH ip_sourcerange=@PHOTOPRISM_IP_SOURCERANGE oauth2=PHOTOPRISM_OAUTH2
