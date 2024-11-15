ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} POSTFIX_RELAY_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} POSTFIX_RELAY_TRAEFIK_HOST "Enter the domain name for this instance" smtp${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} POSTFIX_RELAY_RELAYHOST "Enter the outgoing SMTP server domain:port"
	@${BIN}/reconfigure_ask ${ENV_FILE}  POSTFIX_RELAY_RELAYHOST_USERNAME "Enter the outgoing SMTP server username"
	@${BIN}/reconfigure_ask ${ENV_FILE}  POSTFIX_RELAY_RELAYHOST_PASSWORD "Enter the outgoing SMTP server password"
	@echo
	@${BIN}/reconfigure ${ENV_FILE} POSTFIX_RELAY_POSTFIX_mynetworks="$$(docker network inspect "${PROJECT}_${INSTANCE}" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')"
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE}  POSTFIX_RELAY_MASQUERADED_DOMAINS "Enter the root domains (separated by space) that should mask its sub-domains" $$(${BIN}/dotenv -f ${ROOT_DIR}/${ROOT_ENV} get ROOT_DOMAIN)

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:postfix-relay instance=@POSTFIX_RELAY_INSTANCE

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=postfix-relay
