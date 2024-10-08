ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-no-open
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} MINIO_TRAEFIK_HOST "Enter the minio domain name" s3.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} MINIO_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} MINIO_CONSOLE_TRAEFIK_HOST "Enter the minio console domain name" s3-console.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} MINIO_SITE_REGION "Enter the self-described region of the server" default
	@${BIN}/reconfigure_ask ${ENV_FILE} MINIO_ROOT_USER "Enter the minio root username" root
	@MINIO_ROOT_PASSWORD=$$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_ROOT_PASSWORD); ${BIN}/reconfigure ${ENV_FILE} MINIO_ROOT_PASSWORD=$${MINIO_ROOT_PASSWORD:-$(shell openssl rand -hex 45)}
	@${BIN}/reconfigure_auth ${ENV_FILE} MINIO

.PHONY: bucket # Make a bucket and access credentials
bucket:
	@ENV_FILE=${ENV_FILE} MINIO_TRAEFIK_PORT="$$(${BIN}/dotenv -f ${ROOT_DIR}/${ROOT_ENV} get PUBLIC_HTTPS_PORT)" ./create_bucket_and_user.sh

.PHONY: mc # Run mc shell
mc:
	./mc_shell.sh

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=minio

.PHONY: override-hook
override-hook:
#### This sets the override template variables for docker-compose.instance.yaml:
#### The template dynamically renders to docker-compose.override_{DOCKER_CONTEXT}_{INSTANCE}.yaml
#### These settings are used to automatically generate the service container labels, and traefik config, inside the template.
#### The variable arguments have three forms: `=` `=:` `=@`
####   name=VARIABLE_NAME    # sets the template 'name' field to the value of VARIABLE_NAME found in the .env file
####                         # (this hardcodes the value into docker-compose.override.yaml)
####   name=:VARIABLE_NAME   # sets the template 'name' field to the literal string 'VARIABLE_NAME'
####                         # (this hardcodes the string into docker-compose.override.yaml)
####   name=@VARIABLE_NAME   # sets the template 'name' field to the literal string '${VARIABLE_NAME}'
####                         # (used for regular docker-compose expansion of env vars by name.)
	@${BIN}/docker_compose_override ${ENV_FILE} project=:minio instance=@MINIO_INSTANCE traefik_host=@MINIO_TRAEFIK_HOST http_auth=MINIO_HTTP_AUTH http_auth_var=@MINIO_HTTP_AUTH ip_sourcerange=@S3_SOURCERANGE oauth2=MINIO_OAUTH2 authorized_group=MINIO_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=MINIO_MTLS_AUTH mtls_authorized_certs=MINIO_MTLS_AUTHORIZED_CERTS minio_console_host=@MINIO_CONSOLE_TRAEFIK_HOST minio_console_ip_sourcerange=@CONSOLE_SOURCERANGE

.PHONY: open # Open the web-browser to the service URL
open:
	@export DOCKER_CONTEXT=${DOCKER_CONTEXT}; export ENV_FILE=${ENV_FILE}; export CONTEXT_INSTANCE=${CONTEXT_INSTANCE}; if grep "^open-hook:" "${PROJECT_MAKEFILE}" >/dev/null 2>&1; then echo ok ; make -e --no-print-directory open-hook; else ${BIN}/open; fi
	@echo
	@echo "Login   : $$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_ROOT_USER)"
	@echo "Password: $$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_ROOT_PASSWORD)"
	@echo

