ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} COPYPARTY_TRAEFIK_HOST "Enter the copyparty domain name" copyparty${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} COPYPARTY_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} COPYPARTY
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} COPYPARTY_UID "Enter the copyparty user ID (UID) used for all volume file permissions"
	@${BIN}/reconfigure_ask ${ENV_FILE} COPYPARTY_GID "Enter the copyparty group ID (UID) user for all volume file permissions"
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} COPYPARTY_ADMIN_USER "Enter the copyparty admin user name"
	@${BIN}/reconfigure_ask ${ENV_FILE} COPYPARTY_ADMIN_PASSWORD "Enter a password for the admin user - DO NOT USE commas, colons, or spaces" $(shell openssl rand -base64 13)
	@echo
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get COPYPARTY_ENABLE_PUBLIC_ACCESS)" == "true" && echo "yes" || echo "no") "Do you want to allow unauthenticated public access (read only from /public volume)" "?" && ${BIN}/reconfigure ${ENV_FILE} COPYPARTY_ENABLE_PUBLIC_ACCESS=true || ${BIN}/reconfigure ${ENV_FILE} COPYPARTY_ENABLE_PUBLIC_ACCESS=false
	@echo
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get COPYPARTY_ENABLE_GUEST_ACCESS)" == "true" && echo "yes" || echo "no") "Do you want to allow unauthenticated guest access (upload only to /guest volume)" "?" && ${BIN}/reconfigure ${ENV_FILE} COPYPARTY_ENABLE_GUEST_ACCESS=true || ${BIN}/reconfigure ${ENV_FILE} COPYPARTY_ENABLE_GUEST_ACCESS=false
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:copyparty instance=@COPYPARTY_INSTANCE traefik_host=@COPYPARTY_TRAEFIK_HOST http_auth=COPYPARTY_HTTP_AUTH http_auth_var=@COPYPARTY_HTTP_AUTH ip_sourcerange=@COPYPARTY_IP_SOURCERANGE oauth2=COPYPARTY_OAUTH2 authorized_group=COPYPARTY_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=COPYPARTY_MTLS_AUTH mtls_authorized_certs=COPYPARTY_MTLS_AUTHORIZED_CERTS vol_external=COPYPARTY_VOL_EXTERNAL

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=copyparty

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo

