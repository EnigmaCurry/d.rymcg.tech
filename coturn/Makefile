ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} COTURN_TRAEFIK_HOST "Enter the coturn domain name" turn${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} COTURN_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_password ${ENV_FILE} COTURN_STATIC_AUTH_SECRET
	@TRAEFIK_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get COTURN_TRAEFIK_HOST); ${BIN}/reconfigure ${ENV_FILE} COTURN_EXTERNAL_IP=$$(curl -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=$${TRAEFIK_HOST}&type=A" | jq -r ".Answer[0].data")
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:coturn instance=@COTURN_INSTANCE traefik_host=@COTURN_TRAEFIK_HOST

.PHONY: shell # Enter container shell
shell:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'caddy' 'coturn' --default 'coturn'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: credentials # Get ephemeral TURN credentials
credentials:
	@make --no-print-directory docker-compose-shell SERVICE=coturn COMMAND="get-credentials.sh"

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
