ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get AUTOHEAL_CONTAINER_LABEL)" == "all" && echo "yes" || echo "no") "Do you want autoheal to monitor/restart ALL unhealthy containers (no label required)" "?" && ${BIN}/reconfigure ${ENV_FILE} AUTOHEAL_CONTAINER_LABEL=all || ${BIN}/reconfigure_ask ${ENV_FILE} AUTOHEAL_CONTAINER_LABEL "Enter the docker label name for enabling autoheal (eg. \`autoheal\` will watch all containers with the label \`autoheal=true\`)" "autoheal"
	@${BIN}/reconfigure_ask ${ENV_FILE} AUTOHEAL_INTERVAL "Enter how often (in seconds) do you want to check for unhealthy containers" 5

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=autoheal

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
