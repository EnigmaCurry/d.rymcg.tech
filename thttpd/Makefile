ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook # Configure .env file
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} THTTPD_TRAEFIK_HOST "Enter the website domain name" thttpd.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} THTTPD_CACHE_CONTROL "Enter the Cache-Control setting in seconds" 60
#	@${BIN}/reconfigure_htpasswd ${ENV_FILE} THTTPD_HTTP_AUTH

