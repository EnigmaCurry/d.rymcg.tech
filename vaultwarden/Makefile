ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-no-open
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} VAULTWARDEN_TRAEFIK_HOST "Enter the vaultwarden domain name" vaultwarden${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} VAULTWARDEN_INSTANCE=$${instance:-default}
	@test "$$(${BIN}/dotenv -f ${ENV_FILE} get VAULTWARDEN_SIGNUPS_ALLOWED)" == "true" && echo && echo "Warning: Public registration is enabled." && echo "After creating your first account, you may disable registration: \`make disable-registration\`." || true
	@${BIN}/reconfigure_auth ${ENV_FILE} VAULTWARDEN

.PHONY: enable-registration
enable-registration:
	@${BIN}/reconfigure ${ENV_FILE} VAULTWARDEN_SIGNUPS_ALLOWED=true
	@make --no-print-directory install

.PHONY: disable-registration
disable-registration:
	@${BIN}/reconfigure ${ENV_FILE} VAULTWARDEN_SIGNUPS_ALLOWED=false
	@make --no-print-directory install

.PHONY: open
open:
	@ENV_FILE=${ENV_FILE} CONTEXT_INSTANCE=${CONTEXT_INSTANCE} ${BIN}/open "$$(${BIN}/dotenv -f ${ENV_FILE} get VAULTWARDEN_BASE_PATH)/"

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:vaultwarden instance=@VAULTWARDEN_INSTANCE traefik_host=@VAULTWARDEN_TRAEFIK_HOST http_auth=VAULTWARDEN_HTTP_AUTH http_auth_var=@VAULTWARDEN_HTTP_AUTH ip_sourcerange=@VAULTWARDEN_IP_SOURCERANGE oauth2=VAULTWARDEN_OAUTH2 authorized_group=VAULTWARDEN_OAUTH2_AUTHORIZED_GROUP  enable_mtls_auth=VAULTWARDEN_MTLS_AUTH mtls_authorized_certs=VAULTWARDEN_MTLS_AUTHORIZED_CERTS traefik_entrypoint=VAULTWARDEN_TRAEFIK_ENTRYPOINT

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=vaultwarden

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
