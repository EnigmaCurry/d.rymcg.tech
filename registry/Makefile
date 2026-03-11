ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_TRAEFIK_HOST "Enter the registry domain name" registry${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} REGISTRY_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} REGISTRY "Do you want to enable sentry authorization for admin push access? (No means complete free-for-all!)" "http,mtls"
	@${BIN}/reconfigure_password ${ENV_FILE} REGISTRY_HTTP_SECRET
	@echo
	@echo "By default, Registry storage uses a Docker volume. Optionally, you can use an S3 bucket."
	@${BIN}/reconfigure_choose ${ENV_FILE} REGISTRY_STORAGE_BACKEND "Choose the storage backend:" "docker" "s3"
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get REGISTRY_STORAGE_BACKEND) == "s3" ]] && \
		${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_STORAGE_S3_ENDPOINT "Enter the S3 endpoint URL" && \
		${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_STORAGE_S3_REGION "Enter the S3 region" && \
		${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_STORAGE_S3_BUCKET "Enter the S3 bucket name" && \
		${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_STORAGE_S3_ACCESS_KEY "Enter the S3 access key" && \
		${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_STORAGE_S3_SECRET_KEY "Enter the S3 secret key" || true
	@echo
	@${BIN}/confirm $$([[ "$$(${BIN}/dotenv -f ${ENV_FILE} get REGISTRY_PUBLIC)" == "true" ]] && echo "yes" || echo "no") "Do you want to allow public (unauthenticated) read-only pull access" "?" && ${BIN}/reconfigure ${ENV_FILE} REGISTRY_PUBLIC=true || ${BIN}/reconfigure ${ENV_FILE} REGISTRY_PUBLIC=false
	@echo

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:registry instance=@REGISTRY_INSTANCE traefik_host=@REGISTRY_TRAEFIK_HOST http_auth=REGISTRY_HTTP_AUTH http_auth_var=@REGISTRY_HTTP_AUTH ip_sourcerange=@REGISTRY_IP_SOURCERANGE enable_mtls_auth=REGISTRY_MTLS_AUTH mtls_authorized_certs=REGISTRY_MTLS_AUTHORIZED_CERTS storage_backend=REGISTRY_STORAGE_BACKEND s3_endpoint=@REGISTRY_STORAGE_S3_ENDPOINT s3_region=@REGISTRY_STORAGE_S3_REGION s3_bucket=@REGISTRY_STORAGE_S3_BUCKET s3_access_key=@REGISTRY_STORAGE_S3_ACCESS_KEY s3_secret_key=@REGISTRY_STORAGE_S3_SECRET_KEY public=REGISTRY_PUBLIC

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=registry

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
