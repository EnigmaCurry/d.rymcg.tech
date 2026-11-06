ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
 #### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
 #### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
 #### reconfigure sets the value of a variable in the .env file without asking.
 #### reconfigure_auth asks which of HTTP Basic Auth / OAuth2 / mTLS to enable.
 #### reconfigure_password_bcrypt generates a random password + bcrypt hash (only if not set).
 #### confirm asks y/n to enable the optional MCP server and the gethomepage widget.
	@${BIN}/reconfigure_ask ${ENV_FILE} HOMELABLE_TRAEFIK_HOST "Enter the homelable domain name" homelable${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} HOMELABLE_INSTANCE=$${instance:-default}
	@HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_TRAEFIK_HOST) && ${BIN}/reconfigure ${ENV_FILE} "HOMELABLE_CORS_ORIGINS=[\"https://$${HOST}\"]"
	@SECRET=$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_SECRET_KEY) && test -n "$${SECRET}" || ${BIN}/reconfigure ${ENV_FILE} HOMELABLE_SECRET_KEY=$$(openssl rand -hex 32)
	@${BIN}/reconfigure_auth ${ENV_FILE} HOMELABLE
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} HOMELABLE_SCANNER_RANGES "Enter the CIDR ranges to scan (JSON array, eg. [\"192.168.1.0/24\"]) or leave blank" -
	@${BIN}/reconfigure_password_bcrypt ${ENV_FILE} HOMELABLE_AUTH_PASSWORD_HASH
	@echo ""
	@${BIN}/confirm $$(echo "$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_DOCKER_COMPOSE_PROFILES)" | tr ',' '\n' | grep -q '^mcp$$' && echo yes || echo no) "Enable the optional MCP server (AI integration; listens on port 8001 of the Docker host, keep it firewalled to your LAN)?" "?" && ( \
		API_KEY=$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_MCP_API_KEY) && test -n "$${API_KEY}" || ${BIN}/reconfigure ${ENV_FILE} HOMELABLE_MCP_API_KEY=$$(openssl rand -hex 32); \
		SVC_KEY=$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_MCP_SERVICE_KEY) && test -n "$${SVC_KEY}" || ${BIN}/reconfigure ${ENV_FILE} HOMELABLE_MCP_SERVICE_KEY=$$(openssl rand -hex 32); \
		PROFILES=$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_DOCKER_COMPOSE_PROFILES); \
		case ",$${PROFILES}," in *,mcp,) ;; *) ${BIN}/reconfigure ${ENV_FILE} HOMELABLE_DOCKER_COMPOSE_PROFILES="$${PROFILES},mcp" ;; esac \
	) || ( \
		PROFILES=$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_DOCKER_COMPOSE_PROFILES | tr ',' '\n' | grep -v '^mcp$$' | paste -sd, -); \
		${BIN}/reconfigure ${ENV_FILE} HOMELABLE_DOCKER_COMPOSE_PROFILES=$${PROFILES} \
	)
	@echo ""
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_HOMEPAGE_WIDGET_ENABLE)" == 'true' && echo yes || echo no) "Enable the gethomepage widget (read-only stats; note: it only works while mTLS is disabled)?" "?" && ( \
		KEY=$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_HOMEPAGE_WIDGET_API_KEY) && test -n "$${KEY}" || ${BIN}/reconfigure ${ENV_FILE} HOMELABLE_HOMEPAGE_WIDGET_API_KEY=$$(openssl rand -hex 32); \
		${BIN}/reconfigure ${ENV_FILE} HOMELABLE_HOMEPAGE_WIDGET_ENABLE=true \
	) || ( \
		${BIN}/reconfigure ${ENV_FILE} HOMELABLE_HOMEPAGE_WIDGET_ENABLE=false \
	)
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:homelable instance=@HOMELABLE_INSTANCE traefik_host=@HOMELABLE_TRAEFIK_HOST http_auth=HOMELABLE_HTTP_AUTH http_auth_var=@HOMELABLE_HTTP_AUTH ip_sourcerange=@HOMELABLE_IP_SOURCERANGE oauth2=HOMELABLE_OAUTH2 authorized_group=HOMELABLE_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=HOMELABLE_MTLS_AUTH mtls_authorized_certs=HOMELABLE_MTLS_AUTHORIZED_CERTS homepage_labels_enable=HOMELABLE_HOMEPAGE_LABELS_ENABLE homepage_group_homelable=HOMELABLE_HOMEPAGE_GROUP_HOMELABLE homepage_name_homelable=HOMELABLE_HOMEPAGE_NAME_HOMELABLE homepage_icon_homelable=HOMELABLE_HOMEPAGE_ICON_HOMELABLE homepage_description_homelable=HOMELABLE_HOMEPAGE_DESCRIPTION_HOMELABLE homepage_show_stats_homelable=HOMELABLE_HOMEPAGE_SHOW_STATS_HOMELABLE homepage_widget_enable=HOMELABLE_HOMEPAGE_WIDGET_ENABLE homepage_widget_api_key=HOMELABLE_HOMEPAGE_WIDGET_API_KEY

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=frontend

.PHONY: shell-menu
shell-menu:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'frontend' --default 'frontend' 'backend' 'mcp'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
