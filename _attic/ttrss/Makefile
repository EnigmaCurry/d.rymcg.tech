ROOT_DIR = ../..
include ${ROOT_DIR}/_scripts/Makefile.projects-custom-build
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} TTRSS_TRAEFIK_HOST "Enter the ttrss domain name" ttrss${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_password ${ENV_FILE} TTRSS_DB_PASS
	@PUBLIC_HTTPS_PORT="$$(${BIN}/dotenv -f ${ROOT_DIR}/${ROOT_ENV} get PUBLIC_HTTPS_PORT)"; test "$${PUBLIC_HTTPS_PORT}" == "443" && ${BIN}/reconfigure ${ENV_FILE} TTRSS_TRAEFIK_PORT='' || ${BIN}/reconfigure ${ENV_FILE} TTRSS_TRAEFIK_PORT="$${PUBLIC_HTTPS_PORT}"
	@${BIN}/reconfigure_auth ${ENV_FILE} TTRSS

.PHONY: build
build:
	@make --no-print-directory docker-compose-build EXTRA_ARGS="${EXTRA_ARGS}" DOCKER_BUILDKIT=0

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:ttrss instance=@TTRSS_INSTANCE traefik_host=@TTRSS_TRAEFIK_HOST http_auth=TTRSS_HTTP_AUTH http_auth_var=@TTRSS_HTTP_AUTH ip_sourcerange=@TTRSS_IP_SOURCERANGE oauth2=TTRSS_OAUTH2 authorized_group=TTRSS_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=TTRSS_MTLS_AUTH mtls_authorized_certs=TTRSS_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'db' 'app' 'backups' 'updater' 'web-nginx' --default 'app'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
