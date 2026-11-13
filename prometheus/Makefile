ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} PROMETHEUS_METRICS_TRAEFIK_HOST "Enter the metrics portal domain name" metrics${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} PROMETHEUS_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} PROMETHEUS
	@echo
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get PROMETHEUS_NODE_EXPORTER_ENABLED)" == true && echo yes || echo no) "Do you want to run node-exporter to collect the Host system metrics" "?" && ${BIN}/reconfigure ${ENV_FILE} PROMETHEUS_NODE_EXPORTER_ENABLED=true || ${BIN}/reconfigure ${ENV_FILE} PROMETHEUS_NODE_EXPORTER_ENABLED=false
	@echo
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get PROMETHEUS_CADVISOR_ENABLED)" == true && echo yes || echo no) "Do you want to run cAdvisor to collect container metrics" "?" && ${BIN}/reconfigure ${ENV_FILE} PROMETHEUS_CADVISOR_ENABLED=true || ${BIN}/reconfigure ${ENV_FILE} PROMETHEUS_CADVISOR_ENABLED=false
	@echo
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get PROMETHEUS_ALERTMANAGER_ENABLED)" == true && echo yes || echo no) "Do you want to run alertmanager to collect container metrics" "?" && ${BIN}/reconfigure ${ENV_FILE} PROMETHEUS_ALERTMANAGER_ENABLED=true || ${BIN}/reconfigure ${ENV_FILE} PROMETHEUS_ALERTMANAGER_ENABLED=false
	@echo
	@test "$$(${BIN}/dotenv -f ${ENV_FILE} get PROMETHEUS_ALERTMANAGER_ENABLED)" == true && (${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get PROMETHEUS_ALERTMANAGER_SMTP_ENABLED)" == true && echo yes || echo no) "Do you want to send notifications via SMTP (email)" "?" && ${BIN}/reconfigure ${ENV_FILE} PROMETHEUS_ALERTMANAGER_SMTP_ENABLED=true || ${BIN}/reconfigure ${ENV_FILE} PROMETHEUS_ALERTMANAGER_SMTP_ENABLED=false) || ${BIN}/reconfigure ${ENV_FILE} PROMETHEUS_ALERTMANAGER_SMTP_ENABLED=false || true
	@test "$$(${BIN}/dotenv -f ${ENV_FILE} get PROMETHEUS_ALERTMANAGER_SMTP_ENABLED)" == true && ${BIN}/reconfigure_ask ${ENV_FILE} PROMETHEUS_ALERTMANAGER_SMTP_FROM "Enter the SMTP default sender from address" prometheus@${ROOT_DOMAIN} || true
	@test "$$(${BIN}/dotenv -f ${ENV_FILE} get PROMETHEUS_ALERTMANAGER_SMTP_ENABLED)" == true && ${BIN}/reconfigure_ask ${ENV_FILE} PROMETHEUS_ALERTMANAGER_SMTP_TO "Enter the email address to send notifications to" || true
	@test "$$(${BIN}/dotenv -f ${ENV_FILE} get PROMETHEUS_ALERTMANAGER_SMTP_ENABLED)" == true && ${BIN}/reconfigure_ask_host_port ${ENV_FILE} PROMETHEUS_ALERTMANAGER_SMTP_SMARTHOST "Enter the SMTP smarthost domain and port" "smtp.example.com:465" || true
	@test "$$(${BIN}/dotenv -f ${ENV_FILE} get PROMETHEUS_ALERTMANAGER_SMTP_ENABLED)" == true && ${BIN}/reconfigure_ask_email_address ${ENV_FILE} PROMETHEUS_ALERTMANAGER_SMTP_AUTH_USERNAME "Enter the SMTP authentication username" "user@example.com" || true
	@test "$$(${BIN}/dotenv -f ${ENV_FILE} get PROMETHEUS_ALERTMANAGER_SMTP_ENABLED)" == true && ${BIN}/reconfigure_ask ${ENV_FILE} PROMETHEUS_ALERTMANAGER_SMTP_AUTH_PASSWORD "Enter the SMTP authentication password"  || true
	@echo
	@make --no-print-directory compose-profiles

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:prometheus instance=@PROMETHEUS_INSTANCE traefik_host=@PROMETHEUS_METRICS_TRAEFIK_HOST http_auth=PROMETHEUS_HTTP_AUTH http_auth_var=@PROMETHEUS_HTTP_AUTH ip_sourcerange=@PROMETHEUS_METRICS_IP_SOURCERANGE oauth2=PROMETHEUS_OAUTH2 authorized_group=PROMETHEUS_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=PROMETHEUS_MTLS_AUTH mtls_authorized_certs=PROMETHEUS_MTLS_AUTHORIZED_CERTS traefik_entrypoint=PROMETHEUS_METRICS_TRAEFIK_ENTRYPOINT

.PHONY: compose-profiles
compose-profiles:
	@${BIN}/reconfigure_compose_profiles ${ENV_FILE} PROMETHEUS_NODE_EXPORTER_ENABLED=node-exporter PROMETHEUS_CADVISOR_ENABLED=cadvisor PROMETHEUS_ALERTMANAGER_ENABLED=alertmanager

.PHONY: shell
shell:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'node-exporter' 'prometheus' 'grafana' 'cadvisor' 'alertmanager' 'alert-test' --default 'grafana'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: local-alertmanager # Forward alerts to local environment
local-alertmanager:
	@export ENV_FILE=${ENV_FILE} CONTEXT_INSTANCE=${CONTEXT_INSTANCE} PORT_FORWARD="$$(${BIN}/port_forward ${ENV_FILE} alertmanager 9093)"; if [[ ! "$${PORT_FORWARD}" =~ [0-9]+ ]]; then ${BIN}/fault "Could not get the SSH forwarded port"; else echo "Local port forward established on localhost:$${PORT_FORWARD}"; fi;

.PHONY: test-alert # Perform a test alert
test-alert:
	@docker compose --env-file ${ENV_FILE} run --rm -it alert-test
	@echo
	@echo "Sent test alert"

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
