ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} WOODPECKER_TRAEFIK_HOST "Enter the woodpecker server domain name" woodpecker${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} WOODPECKER_GRPC_HOST "Enter the woodpecker GRPC domain name" woodpecker-grpc${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_password ${ENV_FILE} WOODPECKER_AGENT_SECRET
	@echo ""
	@forge=$$(eval "${BIN}/script-wizard choose 'Which forge do you want to use?' 'Forgejo' --default 'Forgejo'") && \
	if [ "$${forge}" = "Forgejo" ]; then \
		${BIN}/reconfigure ${ENV_FILE} WOODPECKER_FORGEJO=true; \
		${BIN}/reconfigure_ask ${ENV_FILE} WOODPECKER_FORGEJO_URL "Enter the Forgejo server URL" https://git.${ROOT_DOMAIN}; \
		FORGEJO_URL=$$(${BIN}/dotenv -f ${ENV_FILE} get WOODPECKER_FORGEJO_URL); \
		TRAEFIK_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get WOODPECKER_TRAEFIK_HOST); \
		echo ""; \
		echo "## Create an OAuth2 application in Forgejo:"; \
		echo "  1. Open $${FORGEJO_URL}/user/settings/applications"; \
		echo "  2. Enter Application Name: Woodpecker"; \
		echo "  3. Enter Redirect URI: https://$${TRAEFIK_HOST}/authorize"; \
		echo "  4. Copy the Client ID and Client Secret."; \
		echo ""; \
		${BIN}/reconfigure_ask ${ENV_FILE} WOODPECKER_FORGEJO_CLIENT "Enter the Forgejo OAuth2 Client ID"; \
		${BIN}/reconfigure_ask ${ENV_FILE} WOODPECKER_FORGEJO_SECRET "Enter the Forgejo OAuth2 Client Secret"; \
		${BIN}/reconfigure_ask ${ENV_FILE} WOODPECKER_ADMIN "Enter the Forgejo admin username(s), not email (comma separated)"; \
		${BIN}/reconfigure_ask ${ENV_FILE} WOODPECKER_OPEN "Allow any Forgejo user to login?" false; \
	fi
	@echo ""
	@${BIN}/reconfigure ${ENV_FILE} WOODPECKER_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_compose_profiles_select ${ENV_FILE} server="Woodpecker Server" agent="Woodpecker Agent"
	@${BIN}/reconfigure_choose ${ENV_FILE} WOODPECKER_BACKEND "Choose the agent backend" "docker" "local"
	@role=$$(eval "${BIN}/script-wizard choose 'Configure this agent with role=controller filter label?' 'no' 'yes' --default 'no'") && \
	if [ "$${role}" = "yes" ]; then \
		${BIN}/reconfigure ${ENV_FILE} WOODPECKER_FILTER_LABELS=role=controller; \
	else \
		${BIN}/reconfigure ${ENV_FILE} WOODPECKER_FILTER_LABELS=; \
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:woodpecker instance=@WOODPECKER_INSTANCE traefik_host=@WOODPECKER_TRAEFIK_HOST grpc_host=@WOODPECKER_GRPC_HOST ip_sourcerange=@WOODPECKER_IP_SOURCERANGE

.PHONY: install-hook-pre
install-hook-pre:

.PHONY: install-hook
install-hook:

.PHONY: droplet # Manage Woodpecker agent droplets on DigitalOcean
droplet:
	@DEFAULT_WOODPECKER_SERVER="$$(${BIN}/dotenv -f ${ENV_FILE} get WOODPECKER_GRPC_HOST):443" \
	DEFAULT_WOODPECKER_AGENT_SECRET="$$(${BIN}/dotenv -f ${ENV_FILE} get WOODPECKER_AGENT_SECRET)" \
	bash scripts/agent-droplet.sh

.PHONY: droplet-preset # Create a Woodpecker agent droplet preset
droplet-preset:
	@DEFAULT_WOODPECKER_SERVER="$$(${BIN}/dotenv -f ${ENV_FILE} get WOODPECKER_GRPC_HOST):443" \
	DEFAULT_WOODPECKER_AGENT_SECRET="$$(${BIN}/dotenv -f ${ENV_FILE} get WOODPECKER_AGENT_SECRET)" \
	bash scripts/agent-droplet.sh gumdrop_create_preset

.PHONY: shell # Enter one of the container shells
shell:
	@container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'server' 'agent' --default 'server'") && make --no-print-directory docker-compose-shell SERVICE=$${container}
