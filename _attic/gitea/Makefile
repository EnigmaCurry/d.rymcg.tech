ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} GITEA_TRAEFIK_HOST "Enter your gitea domain name" git${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} GITEA_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} APP_NAME "Enter the service description" "$${instance:-default} - git hosting"
	@PUBLIC_HTTPS_PORT="$$(${BIN}/dotenv -f ${ROOT_DIR}/${ROOT_ENV} get PUBLIC_HTTPS_PORT)"; test -n "$${PUBLIC_HTTPS_PORT}" && ${BIN}/reconfigure ${ENV_FILE} "GITEA__server__ROOT_URL=https://$$(${BIN}/dotenv -f ${ENV_FILE} get GITEA_TRAEFIK_HOST):$${PUBLIC_HTTPS_PORT}" || ${BIN}/reconfigure ${ENV_FILE} "GITEA__server__ROOT_URL=https://$$(${BIN}/dotenv -f ${ENV_FILE} get GITEA_TRAEFIK_HOST)"

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=gitea
