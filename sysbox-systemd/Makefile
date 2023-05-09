ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} SYSBOX_SYSTEMD_INSTANCE=$${instance:-default}

.PHONY: shell
shell:
	@set -x; docker compose --project-name sysbox-systemd_$${instance:-default} --env-file ${ENV_FILE} exec -it $${service:-linux} /bin/bash
