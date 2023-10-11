ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} PIWIGO_TRAEFIK_HOST "Enter the piwigo domain name" pics${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_password ${ENV_FILE} PIWIGO_MARIADB_ROOT_PASSWORD
	@${BIN}/reconfigure_password ${ENV_FILE} PIWIGO_MARIADB_PASSWORD
	@${BIN}/reconfigure_ask ${ENV_FILE} TIMEZONE "Enter your timezone" UTC
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} PIWIGO_HTTP_AUTH default=no
	@${BIN}/reconfigure_oauth2 ${ENV_FILE} PIWIGO_OAUTH2 default=$$( ${BIN}/dotenv -f ${ENV_FILE} get PIWIGO_OAUTH2 ) PIWIGO_AUTHORIZED_IDENTITIES
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:piwigo instance=@PIWIGO_INSTANCE traefik_host=@PIWIGO_TRAEFIK_HOST http_auth=PIWIGO_HTTP_AUTH http_auth_var=@PIWIGO_HTTP_AUTH ip_sourcerange=@PIWIGO_IP_SOURCERANGE oauth2=PIWIGO_OAUTH2 authorized_emails=PIWIGO_AUTHORIZED_IDENTITIES
