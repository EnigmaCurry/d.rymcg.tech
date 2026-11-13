ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} CADDY_TRAEFIK_HOST "Enter the caddy domain name" caddy${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} CADDY_INSTANCE=$${instance:-default}
	@echo ""
#### Choose who terminates TLS (traefik is the default, passthrough is experimental):
	@${BIN}/reconfigure_choose ${ENV_FILE} CADDY_TLS_MODE "Who should terminate TLS? (traefik is recommended; passthrough is experimental, Caddy gets its own cert)" "traefik" "passthrough"
	@echo ""
#### Configure auth (only available when Traefik terminates TLS):
	@if [ "$$(${BIN}/dotenv -f ${ENV_FILE} get CADDY_TLS_MODE)" = "passthrough" ]; then \
		echo "TLS passthrough mode: Traefik auth/mTLS middlewares are not available, skipping auth config."; \
	else \
		${BIN}/reconfigure_auth ${ENV_FILE} CADDY; \
	fi

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:caddy instance=@CADDY_INSTANCE traefik_host=@CADDY_TRAEFIK_HOST ip_sourcerange=@CADDY_IP_SOURCERANGE tls_mode=CADDY_TLS_MODE http_auth=CADDY_HTTP_AUTH http_auth_var=@CADDY_HTTP_AUTH oauth2=CADDY_OAUTH2 authorized_group=CADDY_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=CADDY_MTLS_AUTH mtls_authorized_certs=CADDY_MTLS_AUTHORIZED_CERTS traefik_entrypoint=CADDY_TRAEFIK_ENTRYPOINT

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=caddy

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
