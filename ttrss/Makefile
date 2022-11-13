ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook # Configure .env file
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} TTRSS_TRAEFIK_HOST "Enter the ttrss domain name" ttrss.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} TTRSS_DB_PASS="$$(openssl rand -base64 45)"
