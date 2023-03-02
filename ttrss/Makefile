ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-custom-build

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} TTRSS_TRAEFIK_HOST "Enter the ttrss domain name" ttrss.${ROOT_DOMAIN}
	@${BIN}/reconfigure_password ${ENV_FILE} TTRSS_DB_PASS
	@PUBLIC_HTTPS_PORT="$$(${BIN}/dotenv -f ${ROOT_DIR}/${ROOT_ENV} get PUBLIC_HTTPS_PORT)"; test "$${PUBLIC_HTTPS_PORT}" == "443" && ${BIN}/reconfigure ${ENV_FILE} TTRSS_TRAEFIK_PORT='' || ${BIN}/reconfigure ${ENV_FILE} TTRSS_TRAEFIK_PORT="$${PUBLIC_HTTPS_PORT}"

.PHONY: build
build:
	@make --no-print-directory docker-compose-build EXTRA_ARGS="${EXTRA_ARGS}" DOCKER_BUILDKIT=0
