ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} SPEEDTEST_TRACKER_TRAEFIK_HOST "Enter the speedtest-tracker domain name" speedtest-tracker${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} SPEEDTEST_TRACKER_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} SPEEDTEST_TRACKER
	@echo
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} SPEEDTEST_TRACKER_APP_NAME "Enter the application's name as it will appear on the dashboard and in notifications. Or leave this bank to use the default (\"Speedtest Tracker\")"
	@echo
	@${BIN}/reconfigure_password ${ENV_FILE} SPEEDTEST_TRACKER_INITIAL_ADMIN_PASSWORD 15
	@echo
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get SPEEDTEST_TRACKER_PUBLIC_DASHBOARD)" == 'false' && echo no || echo yes) "Do you want enable a public dashboard for guest (unauthenticated) users" "?" && \
		${BIN}/reconfigure ${ENV_FILE} SPEEDTEST_TRACKER_PUBLIC_DASHBOARD=true || \
		${BIN}/reconfigure ${ENV_FILE} SPEEDTEST_TRACKER_PUBLIC_DASHBOARD=false
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} SPEEDTEST_TRACKER_DISPLAY_TIMEZONE "Enter the timezone you want timestamps to be displayed in"
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} SPEEDTEST_TRACKER_SCHEDULE "Enter the cron expression used to run speedtests on a scheduled basis"
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} SPEEDTEST_TRACKER_PRUNE_RESULTS_OLDER_THAN "Enter the number of days to keep results for, or enter 0 (zero) to keep all results"
	@echo
	@${BIN}/reconfigure ${ENV_FILE} SPEEDTEST_TRACKER_APP_KEY=$$(openssl rand -base64 32)
	@${BIN}/reconfigure ${ENV_FILE} SPEEDTEST_TRACKER_APP_KEY=$$(key=$$(${BIN}/dotenv -f ${ENV_FILE} get SPEEDTEST_TRACKER_APP_KEY); [[ "$${key}" == base64:* ]] && echo "$${key}" || echo "base64:$${key}")
	@echo
	@make show-password && echo && sleep 1

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

.PHONY: show-password # Show the admin login's initial password
show-password:
	@echo
	@echo "The initial password for the admin login is:  $$(${BIN}/dotenv -f ${ENV_FILE} get SPEEDTEST_TRACKER_INITIAL_ADMIN_PASSWORD)"
	@echo
	@echo "You should immediately open the app, click your avatar in the upper right corner, and select "Profile" to change the admin login's password (also, optionally, to change the admin login's name and email address). Once you change the password in the app, this initial password is no longer used."
	@echo

.PHONY: install-hook
install-hook:
	@echo
