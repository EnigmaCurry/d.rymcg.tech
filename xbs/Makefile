ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} XBS_TRAEFIK_HOST "Enter the xbs domain name" xbs${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} XBS_LOCATION "Enter the xbs location"
	@${BIN}/reconfigure_ask ${ENV_FILE} XBS_MESSAGE "Enter the xbs welcome message"

	@${BIN}/reconfigure_password ${ENV_FILE} XBS_DB_PASSWORD
	@${BIN}/reconfigure_auth ${ENV_FILE} XBS

.PHONY: shell
shell:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'db' 'api' --default 'api'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:xbs instance=@XBS_INSTANCE traefik_host=@XBS_TRAEFIK_HOST http_auth=XBS_HTTP_AUTH http_auth_var=@XBS_HTTP_AUTH ip_sourcerange=@XBS_IP_SOURCERANGE oauth2=XBS_OAUTH2 authorized_group=XBS_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=XBS_MTLS_AUTH mtls_authorized_certs=XBS_MTLS_AUTHORIZED_CERTS

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
