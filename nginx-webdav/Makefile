ROOT_DIR = ..
include ../_scripts/Makefile.projects
include ../_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} NGINX_WEBDAV_TRAEFIK_HOST "Enter the WebDAV domain name" dav${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} NGINX_WEBDAV_INSTANCE=${instance}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} NGINX_WEBDAV_HTTP_AUTH

.PHONY: shell
shell:
	docker compose --env-file=${ENV_FILE} exec -it thttpd /bin/sh
