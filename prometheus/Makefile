ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} PROMETHEUS_METRICS_TRAEFIK_HOST "Enter the metrics portal domain name" metrics${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} PROMETHEUS_INSTANCE=$${instance:-default}
	@echo
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get PROMETHEUS_NODE_EXPORTER_ENABLED)" == true && echo yes || echo no) "Do you want to run node-exporter to collect the Host system metrics" "?" && ${BIN}/reconfigure ${ENV_FILE} PROMETHEUS_NODE_EXPORTER_ENABLED=true || ${BIN}/reconfigure ${ENV_FILE} PROMETHEUS_NODE_EXPORTER_ENABLED=false
	@echo
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get PROMETHEUS_CADVISOR_ENABLED)" == true && echo yes || echo no) "Do you want to run cAdvisor to collect container metrics" "?" && ${BIN}/reconfigure ${ENV_FILE} PROMETHEUS_CADVISOR_ENABLED=true || ${BIN}/reconfigure ${ENV_FILE} PROMETHEUS_CADVISOR_ENABLED=false
#	@test "$$(${BIN}/dotenv -f ${ENV_FILE} get PROMETHEUS_CADVISOR_ENABLED)" == true && ${BIN}/reconfigure_ask ${ENV_FILE} PROMETHEUS_CADVISOR_TRAEFIK_HOST "Enter the cadvisor dashboard domain name" cadvisor${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN} || true
	@make --no-print-directory compose-profiles

.PHONY: compose-profiles
compose-profiles:
	@${BIN}/reconfigure_compose_profiles ${ENV_FILE} PROMETHEUS_NODE_EXPORTER_ENABLED=node-exporter PROMETHEUS_CADVISOR_ENABLED=cadvisor

.PHONY: shell
shell:
	@docker-compose --env-file ${ENV_FILE} exec -it $${service:-grafana} /bin/sh -c "/bin/bash || /bin/sh"
