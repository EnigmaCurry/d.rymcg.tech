ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} PRIVATEBIN_TRAEFIK_HOST "Enter the privatebin domain name" bin.${ROOT_DOMAIN}
