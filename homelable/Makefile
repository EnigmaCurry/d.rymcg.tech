ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

## Valid TCP port (1-65535), for reconfigure_ask_validate_regex:
PORT_REGEX = ^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$$

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
	@HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_TRAEFIK_HOST); CORS=$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_CORS_ORIGINS); \
	case "$${CORS}" in \
		*,*) echo "$${CORS}" | grep -qF "\"https://$${HOST}\"" || echo "WARNING: HOMELABLE_CORS_ORIGINS does not include https://$${HOST} (the UI's API calls will fail CORS from there)." ;; \
		*) ${BIN}/reconfigure ${ENV_FILE} "HOMELABLE_CORS_ORIGINS=[\"https://$${HOST}\"]" ;; \
	esac
	@SECRET=$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_SECRET_KEY) && test -n "$${SECRET}" || ${BIN}/reconfigure ${ENV_FILE} HOMELABLE_SECRET_KEY=$$(openssl rand -hex 32)
	@${BIN}/reconfigure_auth ${ENV_FILE} HOMELABLE
	@${BIN}/reconfigure_choose ${ENV_FILE} HOMELABLE_NETWORK_MODE "Choose the backend network mode: 'bridge' keeps the backend on the compose network (safer: no ports exposed on the Docker host, but no MAC addresses and no mDNS discovery); 'host' puts it on the Docker host network (MAC + mDNS discovery work, but the backend port binds directly on the host — keep it firewalled)" "bridge" "host"
	@if test "$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_NETWORK_MODE)" == "host"; then \
		${BIN}/reconfigure_ask_validate_regex ${ENV_FILE} HOMELABLE_BACKEND_PORT "Enter the port the backend listens on (it binds directly on the Docker host; pick a free port)" 8000 "${PORT_REGEX}"; \
	else \
		${BIN}/reconfigure ${ENV_FILE} HOMELABLE_BACKEND_PORT=8000; \
	fi
	@${BIN}/reconfigure_ask_validate_regex ${ENV_FILE} HOMELABLE_SCANNER_RANGES "Enter the CIDR ranges to scan as a JSON array (eg. [\"192.168.1.0/24\"]), or [] for none" "[]" "^\[.*\]$$"
	@${BIN}/reconfigure_password_bcrypt ${ENV_FILE} HOMELABLE_AUTH_PASSWORD_HASH
	@echo ""
	@${BIN}/confirm $$( { test "$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_MCP_ENABLED)" == "true" || ${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_DOCKER_COMPOSE_PROFILES | tr -d ' ' | tr ',' '\n' | grep -q '^mcp$$'; } && echo yes || echo no) "Enable the optional MCP server (AI integration; listens on a port of the Docker host, keep it firewalled to your LAN)" "?" && ${BIN}/reconfigure ${ENV_FILE} HOMELABLE_MCP_ENABLED=true || ${BIN}/reconfigure ${ENV_FILE} HOMELABLE_MCP_ENABLED=false
	@if test "$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_MCP_ENABLED)" == "true"; then \
		API_KEY=$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_MCP_API_KEY) && test -n "$${API_KEY}" || ${BIN}/reconfigure ${ENV_FILE} HOMELABLE_MCP_API_KEY=$$(openssl rand -hex 32); \
		SVC_KEY=$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_MCP_SERVICE_KEY) && test -n "$${SVC_KEY}" || ${BIN}/reconfigure ${ENV_FILE} HOMELABLE_MCP_SERVICE_KEY=$$(openssl rand -hex 32); \
		${BIN}/reconfigure_ask_validate_regex ${ENV_FILE} HOMELABLE_MCP_PORT "Enter the host port for the MCP server (pick a free port on the Docker host)" 8001 "${PORT_REGEX}"; \
	fi
	@${BIN}/reconfigure_compose_profiles ${ENV_FILE} HOMELABLE_MCP_ENABLED=mcp
	@echo ""
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_HOMEPAGE_WIDGET_ENABLE)" == 'true' && echo yes || echo no) "Enable the gethomepage widget (read-only stats; it calls the public Traefik host, so it only works with HTTP Basic Auth, OAuth2 and mTLS all disabled, and with HOMELABLE_IP_SOURCERANGE allowing the homepage server)" "?" && ( \
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:homelable instance=@HOMELABLE_INSTANCE traefik_host=@HOMELABLE_TRAEFIK_HOST network_mode=HOMELABLE_NETWORK_MODE backend_port=HOMELABLE_BACKEND_PORT http_auth=HOMELABLE_HTTP_AUTH http_auth_var=@HOMELABLE_HTTP_AUTH ip_sourcerange=@HOMELABLE_IP_SOURCERANGE oauth2=HOMELABLE_OAUTH2 authorized_group=HOMELABLE_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=HOMELABLE_MTLS_AUTH mtls_authorized_certs=HOMELABLE_MTLS_AUTHORIZED_CERTS homepage_labels_enable=HOMELABLE_HOMEPAGE_LABELS_ENABLE homepage_group_homelable=HOMELABLE_HOMEPAGE_GROUP_HOMELABLE homepage_name_homelable=HOMELABLE_HOMEPAGE_NAME_HOMELABLE homepage_icon_homelable=HOMELABLE_HOMEPAGE_ICON_HOMELABLE homepage_description_homelable=HOMELABLE_HOMEPAGE_DESCRIPTION_HOMELABLE homepage_show_stats_homelable=HOMELABLE_HOMEPAGE_SHOW_STATS_HOMELABLE homepage_widget_enable=HOMELABLE_HOMEPAGE_WIDGET_ENABLE homepage_widget_api_key=HOMELABLE_HOMEPAGE_WIDGET_API_KEY profiles=HOMELABLE_DOCKER_COMPOSE_PROFILES

.PHONY: shell # Enter container shell
shell:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'frontend' --default 'frontend' 'backend' 'mcp'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$(service); \
	fi;

.PHONY: install-hook-pre
install-hook-pre:
 #### install runs install-hook-pre, then start (up -d), then install-hook.
 #### Re-render the override template here, before start, so reconfigure +
 #### install is enough to apply config changes (no separate `make
 #### override` needed) and containers are only recreated once.
	@make -e --no-print-directory override instance=${INSTANCE}

.PHONY: install-hook
install-hook:
 #### up -d --remove-orphans removes containers for services that are
 #### missing from the compose file. Services that only fell out of a
 #### compose profile (e.g. disabling the mcp server) are still in the file,
 #### so up --remove-orphans leaves them running: remove those explicitly
 #### (compose rm accepts --profile to see a profile-excluded service;
 #### -s stops the container first, -f skips the confirmation prompt).
	@if test -z "${service}"; then \
		make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="up -d $(if $(BUILD),,--no-build) --remove-orphans"; \
		if ! ${BIN}/dotenv -f ${ENV_FILE} get HOMELABLE_DOCKER_COMPOSE_PROFILES | tr -d ' ' | tr ',' '\n' | grep -q '^mcp$$'; then \
			make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="--profile mcp rm -sf mcp"; \
		fi; \
	fi
