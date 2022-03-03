ROOT_DIR = ..
include ../_scripts/Makefile.projects-custom-build

.PHONY: build # Build the docker image
build:
	DOCKER_BUILDKIT=1 docker compose --env-file=${ENV_FILE} build --build-arg PROGRAMS="$$(${BIN}/dotenv -f ${ENV_FILE} get PROGRAMS)"

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} RDESKTOP_TRAEFIK_HOST "Enter the remote desktop domain name" rdesktop.${ROOT_DOMAIN}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} RDESKTOP_HTTP_AUTH
	@${BIN}/reconfigure ${ENV_FILE} TZ=UTC
	@${BIN}/reconfigure_ask ${ENV_FILE} PROGRAMS "Enter the additional programs to install"
