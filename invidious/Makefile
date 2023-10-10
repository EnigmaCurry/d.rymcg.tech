ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} INVIDIOUS_TRAEFIK_HOST "Enter the invidious domain name" yt${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_password ${ENV_FILE} INVIDIOUS_POSTGRES_PASSWORD
	@${BIN}/reconfigure ${ENV_FILE} INVIDIOUS_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} INVIDIOUS_HTTP_AUTH default=yes
	@${BIN}/reconfigure_oauth2 ${ENV_FILE} INVIDIOUS_OAUTH2 default=$$( ${BIN}/dotenv -f ${ENV_FILE} get INVIDIOUS_OAUTH2 )
	@echo ""
	@${BIN}/reconfigure_password ${ENV_FILE} INVIDIOUS_HMAC_KEY 32

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:invidious instance=@INVIDIOUS_INSTANCE traefik_host=@INVIDIOUS_TRAEFIK_HOST http_auth=INVIDIOUS_HTTP_AUTH http_auth_var=@INVIDIOUS_HTTP_AUTH ip_sourcerange=@INVIDIOUS_IP_SOURCERANGE oauth2=INVIDIOUS_OAUTH2
