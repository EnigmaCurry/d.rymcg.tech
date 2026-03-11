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

.PHONY: list-tags # List all repository tags on the registry
list-tags:
	@REGISTRY_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get REGISTRY_TRAEFIK_HOST); \
	PUBLIC=$$(${BIN}/dotenv -f ${ENV_FILE} get REGISTRY_PUBLIC); \
	HTTP_AUTH=$$(${BIN}/dotenv -f ${ENV_FILE} get REGISTRY_HTTP_AUTH); \
	MTLS_AUTH=$$(${BIN}/dotenv -f ${ENV_FILE} get REGISTRY_MTLS_AUTH); \
	CURL_OPTS=""; \
	echo "## Registry host: $${REGISTRY_HOST}" >&2; \
	echo "## Public: $${PUBLIC}" >&2; \
	echo "## HTTP_AUTH set: $$([ -n \"$${HTTP_AUTH}\" ] && echo yes || echo no)" >&2; \
	if [[ "$${PUBLIC}" != "true" ]]; then \
		if [[ -n "$${HTTP_AUTH}" ]]; then \
			if [[ -f passwords.json ]]; then \
				echo "## Found passwords.json, reading credentials for ${CONTEXT_INSTANCE}" >&2; \
				USER=$$(jq -r '."${CONTEXT_INSTANCE}"[0].username' passwords.json); \
				PASS=$$(jq -r '."${CONTEXT_INSTANCE}"[0].password' passwords.json); \
				echo "## Username from passwords.json: $${USER}" >&2; \
			fi; \
			if [[ -z "$${USER}" || "$${USER}" == "null" ]]; then \
				USER=$$(echo "$${HTTP_AUTH}" | cut -d: -f1); \
				echo "## Prompting for password (user: $${USER})" >&2; \
				echo "Enter password for $${USER}@$${REGISTRY_HOST}:"; \
				read -rs PASS; \
			fi; \
			CURL_OPTS="--user $${USER}:$${PASS}"; \
		elif [[ "$${MTLS_AUTH}" == "true" ]]; then \
			echo "Error: list-tags with mTLS auth is not implemented." >&2; exit 1; \
		fi; \
	else \
		echo "## Public access enabled, no auth needed" >&2; \
	fi; \
	echo "## Fetching catalog from https://$${REGISTRY_HOST}/v2/_catalog" >&2; \
	CATALOG=$$(curl -sf $${CURL_OPTS} https://$${REGISTRY_HOST}/v2/_catalog); \
	echo "## Catalog response: $${CATALOG}" >&2; \
	repos=$$(echo "$${CATALOG}" | jq -r '.repositories[]' 2>/dev/null); \
	echo "## Repositories found: $${repos:-none}" >&2; \
	for repo in $${repos}; do \
		echo "## Fetching tags for $${repo}" >&2; \
		TAGS_RESPONSE=$$(curl -sf $${CURL_OPTS} https://$${REGISTRY_HOST}/v2/$${repo}/tags/list); \
		echo "## Tags response: $${TAGS_RESPONSE}" >&2; \
		tags=$$(echo "$${TAGS_RESPONSE}" | jq -r '.tags[]' 2>/dev/null); \
		for tag in $${tags}; do \
			echo "$${REGISTRY_HOST}/$${repo}:$${tag}"; \
		done; \
	done

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
