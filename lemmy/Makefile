ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} LEMMY_TRAEFIK_HOST "Enter the lemmy domain name" lemmy${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} LEMMY_INSTANCE=$${instance:-default}
	@echo ""
	@${BIN}/reconfigure_password ${ENV_FILE} LEMMY_POSTGRES_PW 32
	@${BIN}/confirm no "Would you like to reconfigure authentication? (NOTE: this will make your Lemmy instance fully private with no federation features, so don't do this if you want to read from other lemmy instances!)" "" && ${BIN}/reconfigure_auth ${ENV_FILE} LEMMY || true

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:lemmy instance=@LEMMY_INSTANCE traefik_host=@LEMMY_TRAEFIK_HOST http_auth=LEMMY_HTTP_AUTH http_auth_var=@LEMMY_HTTP_AUTH ip_sourcerange=@LEMMY_IP_SOURCERANGE lemmy_private=LEMMY_PRIVATE oauth2=LEMMY_OAUTH2 authorized_group=LEMMY_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=LEMMY_MTLS_AUTH mtls_authorized_certs=LEMMY_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'proxy' 'config' 'lemmy' 'lemmy-ui' 'pictrs' 'postgres' 'postfix' --default 'proxy'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: install-hook
install-hook:
	@echo
