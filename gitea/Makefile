ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask GITEA_TRAEFIK_HOST "Enter your gitea domain name" "git.${ROOT_DOMAIN}"
	@${BIN}/reconfigure_ask APP_NAME "Enter the service description" "git thing"

