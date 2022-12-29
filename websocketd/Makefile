ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-no-open

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} WEBSOCKETD_TRAEFIK_HOST "Enter the websocketd domain name" socket.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} WEBSOCKETD_APP_PATH "Enter the websocketd application path" /app
	@${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get WEBSOCKETD_DEV_CONSOLE) == "true" ]] && echo "yes" || echo "no") "Do you want to enable dev console?" "?" && ${BIN}/reconfigure ${ENV_FILE} WEBSOCKETD_DEV_CONSOLE=true || ${BIN}/reconfigure ${ENV_FILE} WEBSOCKETD_DEV_CONSOLE=false

.PHONY: open # Open dev console
open:
	@${BIN}/open $$(${BIN}/dotenv -f ${ENV_FILE} get WEBSOCKETD_APP_PATH)
