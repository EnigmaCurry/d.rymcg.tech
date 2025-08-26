ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-no-open
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} MAUBOT_TRAEFIK_HOST "Enter the maubot domain name" maubot${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} MAUBOT_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} MATRIX_HOMESERVER "Enter the matrix homeserver"
	@${BIN}/reconfigure_ask ${ENV_FILE} MAUBOT_ADMIN_USER "Enter the maubot admin username to create" admin
	@${BIN}/reconfigure_password ${ENV_FILE} MAUBOT_ADMIN_PASSWORD
	@${BIN}/reconfigure_auth ${ENV_FILE} MAUBOT

.PHONY: open # Open the web-browser to the service URL
open:
	@ENV_FILE="${ENV_FILE}" CONTEXT_INSTANCE="${CONTEXT_INSTANCE}" ${BIN}/open /_matrix/maubot

.PHONY: login
login:
	@echo "Login with the maubot client:"
	@echo "Use the same Admin username/password set in your .env file."
	@echo "Use the Server http://localhost:29316"
	@echo "Set the Alias as localhost"
	@echo ""
	@docker-compose --env-file ${ENV_FILE} exec maubot mbc login
	@echo ""
	@echo "Now login to the matrix account for maubots use:"
	@echo "Enter the Matrix homeserver domain, example: matrix.example.com"
	@echo "Enter the Matrix username by itself, example: maubot"
	@echo "Enter the Matrix password account."
	@docker-compose --env-file ${ENV_FILE} exec maubot mbc auth --update-client

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:maubot instance=@MAUBOT_INSTANCE traefik_host=@MAUBOT_TRAEFIK_HOST http_auth=MAUBOT_HTTP_AUTH http_auth_var=@MAUBOT_HTTP_AUTH ip_sourcerange=@MAUBOT_IP_SOURCERANGE oauth2=MAUBOT_OAUTH2 authorized_group=MAUBOT_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=MAUBOT_MTLS_AUTH mtls_authorized_certs=MAUBOT_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=maubot

.PHONY: install-hook
install-hook:
	@echo
