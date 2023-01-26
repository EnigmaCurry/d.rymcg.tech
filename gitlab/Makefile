ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} GITLAB_TRAEFIK_HOST "Enter your gitlab domain name" "gl.${ROOT_DOMAIN}"
	@${BIN}/reconfigure_ask ${ENV_FILE} APP_NAME "Enter the service description" "git thing"
	@${BIN}/reconfigure ${ENV_FILE} POSTGRES_PASS=$(shell openssl rand -hex 45)
	@${BIN}/reconfigure ${ENV_FILE} GITLAB_ROOT_PASSWORD=$(shell openssl rand -hex 45)
