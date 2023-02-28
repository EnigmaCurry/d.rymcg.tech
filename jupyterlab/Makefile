ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} JUPYTERLAB_TRAEFIK_HOST "Enter the jupyterlab domain name" jupyterlab${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} JUPYTERLAB_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_password ${ENV_FILE} JUPYTERLAB_JUPYTER_TOKEN

.PHONY: shell
shell:
	@docker-compose --env-file ${ENV_FILE} exec jupyterlab /bin/bash

.PHONY: token
token:
	@echo $$(${BIN}/dotenv -f ${ENV_FILE} get JUPYTERLAB_JUPYTER_TOKEN)
