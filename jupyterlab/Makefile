ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} JUPYTERLAB_TRAEFIK_HOST "Enter the jupyterlab domain name" jupyterlab.${ROOT_DOMAIN}

.PHONY: shell
shell:
	@docker-compose --env-file ${ENV_FILE} exec jupyterlab /bin/bash
