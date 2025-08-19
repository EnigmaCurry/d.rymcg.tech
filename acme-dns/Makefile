ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} ACME_DNS_SUBDOMAIN "Enter the acme-dns managed sub-domain" acme-dns.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} ACME_DNS_TRAEFIK_HOST "Enter the acme-dns domain name" auth.$$(${BIN}/dotenv -f ${ENV_FILE} get ACME_DNS_SUBDOMAIN)
	@${BIN}/reconfigure_ask ${ENV_FILE} ACME_DNS_PUBLIC_IP_ADDRESS "Enter the PUBLIC IP address of the Docker host" "10.0.0.42"
	@${BIN}/reconfigure_ask ${ENV_FILE} ACME_DNS_HOSTMASTER "Enter the root domain SOA RNAME address (translated email address; write root@example.com as root.example.com)"
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:acme-dns instance=@ACME_DNS_INSTANCE traefik_host=@ACME_DNS_TRAEFIK_HOST api_ip_sourcerange=@ACME_DNS_API_IP_SOURCERANGE enable_mtls_auth=ACME_DNS_MTLS_AUTH mtls_authorized_certs=ACME_DNS_MTLS_AUTHORIZED_CERTS

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=acmedns

.PHONY: registration-disable
registration-disable:
	${BIN}/reconfigure ${ENV_FILE} ACME_DNS_DISABLE_REGISTRATION=true
	make reinstall

.PHONY: registration-enable
registration-enable:
	${BIN}/reconfigure ${ENV_FILE} ACME_DNS_DISABLE_REGISTRATION=false
	make reinstall
