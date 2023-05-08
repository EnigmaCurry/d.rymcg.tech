ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} SYSBOX_SYSTEMD_INSTANCE=$${instance:-default}

.PHONY: shell
shell:
	@docker compose --env-file ${ENV_FILE} exec -it $${service:-linux} /bin/bash
