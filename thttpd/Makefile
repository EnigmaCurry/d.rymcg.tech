ROOT_DIR = ..
include ../_scripts/Makefile.projects
include ../_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} THTTPD_TRAEFIK_HOST "Enter the website domain name" thttpd.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} THTTPD_INSTANCE=${instance}
#	@${BIN}/reconfigure_htpasswd ${ENV_FILE} THTTPD_HTTP_AUTH

.PHONY: shell
shell:
	docker compose --env-file=${ENV_FILE} exec -it thttpd /bin/sh
