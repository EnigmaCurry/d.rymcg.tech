ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} PLAUSIBLE_TRAEFIK_HOST "Enter the plausible domain name" plausible.${ROOT_DOMAIN}
	@${BIN}/reconfigure_password ${ENV_FILE} PLAUSIBLE_SECRET_KEY_BASE 64
	@${BIN}/reconfigure_password ${ENV_FILE} PLAUSIBLE_POSTGRES_PASSWORD 32
