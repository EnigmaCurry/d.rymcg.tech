ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
	@${BIN}/reconfigure_ask ${ENV_FILE} NOSTR_RS_RELAY_TRAEFIK_HOST "Enter the nostr domain name" nostr${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} NOSTR_RS_RELAY_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} NOSTR_RS_RELAY
	@${BIN}/reconfigure_ask ${ENV_FILE} NOSTR_RS_RELAY_NAME "Enter a logical one-word name for this Nostr instance."
	@${BIN}/reconfigure_ask ${ENV_FILE} NOSTR_RS_RELAY_DESCRIPTION "Enter a description for this Nostr instance."
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:nostr-rs-relay instance=@NOSTR_RS_RELAY_INSTANCE traefik_host=@NOSTR_RS_RELAY_TRAEFIK_HOST http_auth=NOSTR_RS_RELAY_HTTP_AUTH http_auth_var=@NOSTR_RS_RELAY_HTTP_AUTH ip_sourcerange=@NOSTR_RS_RELAY_IP_SOURCERANGE oauth2=NOSTR_RS_RELAY_OAUTH2 authorized_group=NOSTR_RS_RELAY_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=NOSTR_RS_RELAY_MTLS_AUTH mtls_authorized_certs=NOSTR_RS_RELAY_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=nostr-rs-relay
