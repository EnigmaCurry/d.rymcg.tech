ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} ACME_DNS_TRAEFIK_HOST "Enter the acme-dns domain name" acme-dns${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} ACME_DNS_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure ${ENV_FILE} ACME_DNS_ACME_CA_EMAIL=$$(${BIN}/dotenv -f "../traefik/.env_${DOCKER_CONTEXT}_default" get TRAEFIK_ACME_CA_EMAIL)
	@__D_RY_CONFIG_ENTRY=reconfigure_auth ${BIN}/reconfigure_htpasswd ${ENV_FILE} ACME_DNS_HTTP_AUTH
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:acme-dns instance=@ACME_DNS_INSTANCE traefik_host=@ACME_DNS_TRAEFIK_HOST http_auth=ACME_DNS_HTTP_AUTH http_auth_var=@ACME_DNS_HTTP_AUTH ip_sourcerange=@ACME_DNS_IP_SOURCERANGE traefik_dns_entrypoint_var=@ACME_DNS_TRAEFIK_DNS_ENTRYPOINT

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=acme-dns
