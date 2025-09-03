ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-no-open
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} MINIO_TRAEFIK_HOST "Enter the minio domain name" s3.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} MINIO_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} MINIO_SITE_REGION "Enter the self-described region of the server" default
	@${BIN}/reconfigure_ask ${ENV_FILE} MINIO_ROOT_USER "Enter the minio root username" root
	@MINIO_ROOT_PASSWORD=$$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_ROOT_PASSWORD); ${BIN}/reconfigure ${ENV_FILE} MINIO_ROOT_PASSWORD=$${MINIO_ROOT_PASSWORD:-$(shell openssl rand -hex 45)}
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} MINIO_CONSOLE_TRAEFIK_HOST "Ener the console domain name" s3-console.${ROOT_DOMAIN};
	@echo
	@echo "You can limit traffic based on source IP address for MinIO's S3 API and/or the console, by expressing an IP range filter."
	@echo "  Example: 0.0.0.0/0 allows all IPs."
	@echo "  Example: 0.0.0.0/32 disables all access."
	@echo "  Example: 192.168.1.1/32 limits access to the single IP address 192.168.1.1."
	@echo "Use CIDR notation. You can specify multiple, separated by commas, enclose entire value in double-quotes."
	@echo "  Example: CONSOLE_SOURCERANGE=\"192.168.1.0/24,10.15.0.2/32\""
	@${BIN}/reconfigure_ask ${ENV_FILE} S3_SOURCERANGE "Enter the IP source range for the S3 API"
	@${BIN}/reconfigure_ask ${ENV_FILE} CONSOLE_SOURCERANGE "Enter the IP source range for the console"
	@${BIN}/reconfigure ${ENV_FILE} MINIO_CONSOLE_ACCESS_KEY=console;
	@${BIN}/reconfigure_password ${ENV_FILE} MINIO_CONSOLE_SECRET_KEY 45;
	@${BIN}/reconfigure_password ${ENV_FILE} MINIO_CONSOLE_PASSPHRASE 45;
	@${BIN}/reconfigure_password ${ENV_FILE} MINIO_CONSOLE_SALT 45;
	@echo
	@${BIN}/reconfigure_auth ${ENV_FILE} MINIO

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:minio instance=@MINIO_INSTANCE traefik_host=@MINIO_TRAEFIK_HOST http_auth=MINIO_HTTP_AUTH http_auth_var=@MINIO_HTTP_AUTH ip_sourcerange=@S3_SOURCERANGE oauth2=MINIO_OAUTH2 authorized_group=MINIO_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=MINIO_MTLS_AUTH mtls_authorized_certs=MINIO_MTLS_AUTHORIZED_CERTS console_host=@MINIO_CONSOLE_TRAEFIK_HOST console_ip_sourcerange=@CONSOLE_SOURCERANGE

.PHONY: shell
shell:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'minio' 'console' 'mc' --default 'minio'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: open # Open the web-browser to the service URL
open:
	@export DOCKER_CONTEXT=${DOCKER_CONTEXT}; export ENV_FILE=${ENV_FILE}; export CONTEXT_INSTANCE=${CONTEXT_INSTANCE}; if grep "^open-hook:" "${PROJECT_MAKEFILE}" >/dev/null 2>&1; then echo ok ; make -e --no-print-directory open-hook; else ${BIN}/open / "$$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_CONSOLE_TRAEFIK_HOST)" https; fi
	@echo
	@echo "Login   : $$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_ROOT_USER)"
	@echo "Password: $$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_ROOT_PASSWORD)"
	@echo

.PHONY: bucket # Make a bucket and access credentials
bucket:
	@ENV_FILE=${ENV_FILE} MINIO_TRAEFIK_PORT="$$(${BIN}/dotenv -f ${ROOT_DIR}/${ROOT_ENV} get PUBLIC_HTTPS_PORT)" ./create_bucket_and_user.sh

.PHONY: mc # Run mc shell
mc:
	./mc_shell.sh

.PHONY: config-console # Configure console to connect to MinIO
config-console:
	@ENV_FILE=${ENV_FILE} MINIO_TRAEFIK_HOST="$$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_TRAEFIK_HOST)" MINIO_TRAEFIK_PORT="$$(${BIN}/dotenv -f ${ROOT_DIR}/${ROOT_ENV} get PUBLIC_HTTPS_PORT)" MINIO_CONSOLE_TRAEFIK_HOST="$$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_CONSOLE_TRAEFIK_HOST)" MINIO_CONSOLE_ACCESS_KEY="$$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_CONSOLE_ACCESS_KEY)" MINIO_CONSOLE_SECRET_KEY="$$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_CONSOLE_SECRET_KEY)" MINIO_ROOT_USER="$$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_ROOT_USER)" MINIO_ROOT_PASSWORD="$$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_ROOT_PASSWORD)" ./config_console.sh

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
