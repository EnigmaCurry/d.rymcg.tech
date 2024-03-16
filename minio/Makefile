ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-no-open

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} MINIO_TRAEFIK_HOST "Enter the minio domain name" s3.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} MINIO_CONSOLE_TRAEFIK_HOST "Enter the minio domain name" s3-console.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} MINIO_SITE_REGION "Enter the self-described region of the server" default
	@${BIN}/reconfigure_ask ${ENV_FILE} MINIO_ROOT_USER "Enter the minio root username" root
	@MINIO_ROOT_PASSWORD=$$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_ROOT_PASSWORD); ${BIN}/reconfigure ${ENV_FILE} MINIO_ROOT_PASSWORD=$${MINIO_ROOT_PASSWORD:-$(shell openssl rand -hex 45)}

.PHONY: bucket # Make a bucket and access credentials
bucket:
	@ENV_FILE=${ENV_FILE} MINIO_TRAEFIK_PORT="$$(${BIN}/dotenv -f ${ROOT_DIR}/${ROOT_ENV} get PUBLIC_HTTPS_PORT)" ./create_bucket_and_user.sh

.PHONY: mc # Run mc shell
mc:
	./mc_shell.sh

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=minio

.PHONY: open # Open the web-browser to the service URL
open:
	@export DOCKER_CONTEXT=${DOCKER_CONTEXT}; export ENV_FILE=${ENV_FILE}; export CONTEXT_INSTANCE=${CONTEXT_INSTANCE}; if grep "^open-hook:" "${PROJECT_MAKEFILE}" >/dev/null 2>&1; then echo ok ; make -e --no-print-directory open-hook; else ${BIN}/open; fi
	@echo
	@echo "Login   : $$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_ROOT_USER)"
	@echo "Password: $$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_ROOT_PASSWORD)"
	@echo

