ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} GITEA_TRAEFIK_HOST "Enter your gitea domain name" "git.${ROOT_DOMAIN}"
	@${BIN}/reconfigure_ask ${ENV_FILE} APP_NAME "Enter the service description" "git thing"

