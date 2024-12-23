ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} SPEEDTEST_TRACKER_TRAEFIK_HOST "Enter the speedtest-tracker domain name" speedtest-tracker${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} SPEEDTEST_TRACKER_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} SPEEDTEST_TRACKER
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} SPEEDTEST_TRACKER_ADMIN_NAME "Enter the admin user's login name" 
	@${BIN}/reconfigure_ask ${ENV_FILE} SPEEDTEST_TRACKER_ADMIN_EMAIL "Enter the admin user's email" 
	@${BIN}/reconfigure_ask ${ENV_FILE} SPEEDTEST_TRACKER_ADMIN_PASSWORD "Enter the admin user's password" 
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} SPEEDTEST_TRACKER_DISPLAY_TIMEZONE "Enter the server's timezone" 
	@echo
	@${BIN}/reconfigure_password ${ENV_FILE} SPEEDTEST_TRACKER_APP_KEY 32
	@${BIN}/reconfigure ${ENV_FILE} SPEEDTEST_TRACKER_APP_KEY=$$(key=$$(${BIN}/dotenv -f ${ENV_FILE} get SPEEDTEST_TRACKER_APP_KEY); [[ "$${key}" == base64:* ]] && echo "$${key}" || echo "base64:$${key}")
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} SPEEDTEST_TRACKER_UID "Enter the host UID to map to the container UID" 
	@${BIN}/reconfigure_ask ${ENV_FILE} SPEEDTEST_TRACKER_GID "Enter the host GID to map to the container GID" 
	@echo

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:speedtest-tracker instance=@SPEEDTEST_TRACKER_INSTANCE traefik_host=@SPEEDTEST_TRACKER_TRAEFIK_HOST http_auth=SPEEDTEST_TRACKER_HTTP_AUTH http_auth_var=@SPEEDTEST_TRACKER_HTTP_AUTH ip_sourcerange=@SPEEDTEST_TRACKER_IP_SOURCERANGE oauth2=SPEEDTEST_TRACKER_OAUTH2 authorized_group=SPEEDTEST_TRACKER_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=SPEEDTEST_TRACKER_MTLS_AUTH mtls_authorized_certs=SPEEDTEST_TRACKER_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=speedtest-tracker
