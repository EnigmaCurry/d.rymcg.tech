ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} FRESHRSS_TRAEFIK_HOST "Enter the ttrss domain name" freshrss.${ROOT_DOMAIN}

