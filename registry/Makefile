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
		${BIN}/reconfigure_ask ${ENV_FILE} REGISTRY_STORAGE_S3_REGION "Enter the S3 region (use 'auto' for Cloudflare R2)" && \
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:registry instance=@REGISTRY_INSTANCE traefik_host=@REGISTRY_TRAEFIK_HOST http_auth=REGISTRY_HTTP_AUTH http_auth_var=@REGISTRY_HTTP_AUTH ip_sourcerange=@REGISTRY_IP_SOURCERANGE enable_mtls_auth=REGISTRY_MTLS_AUTH mtls_authorized_certs=REGISTRY_MTLS_AUTHORIZED_CERTS storage_backend=REGISTRY_STORAGE_BACKEND public=REGISTRY_PUBLIC

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=registry

.PHONY: login # Docker login to the registry
login:
	@if [[ ! -f ${ENV_FILE} ]]; then echo "Error: config file not found: ${ENV_FILE}" >&2; echo "Run 'make config' first." >&2; exit 1; fi; \
	REGISTRY_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get REGISTRY_TRAEFIK_HOST); \
	CI=${CONTEXT_INSTANCE}; \
	if [[ -f passwords.json ]]; then \
		USER=$$(jq -r --arg key "$${CI}" '.[$$key][0].username // empty' passwords.json 2>/dev/null); \
		PASS=$$(jq -r --arg key "$${CI}" '.[$$key][0].password // empty' passwords.json 2>/dev/null); \
	fi; \
	readarray -t CONTEXTS < <(docker context ls --format '{{.Name}}'); \
	CONTEXT=$$(eval "${BIN}/script-wizard choose 'Which Docker context do you want to login from?' $${CONTEXTS[@]@Q} --default ${DOCKER_CONTEXT}"); \
	docker --context "$${CONTEXT}" logout "$${REGISTRY_HOST}" 2>/dev/null || true; \
	if [[ -n "$${USER}" && -n "$${PASS}" ]]; then \
		echo "$${PASS}" | docker --context "$${CONTEXT}" login "$${REGISTRY_HOST}" -u "$${USER}" --password-stdin; \
	else \
		docker --context "$${CONTEXT}" login "$${REGISTRY_HOST}"; \
	fi

.PHONY: list-tags # List all repository tags on the registry
list-tags:
	@if [[ ! -f ${ENV_FILE} ]]; then echo "Error: config file not found: ${ENV_FILE}" >&2; echo "Run 'make config' first." >&2; exit 1; fi; \
	REGISTRY_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get REGISTRY_TRAEFIK_HOST); \
	PUBLIC=$$(${BIN}/dotenv -f ${ENV_FILE} get REGISTRY_PUBLIC); \
	HTTP_AUTH=$$(${BIN}/dotenv -f ${ENV_FILE} get REGISTRY_HTTP_AUTH); \
	MTLS_AUTH=$$(${BIN}/dotenv -f ${ENV_FILE} get REGISTRY_MTLS_AUTH); \
	CURL_OPTS=""; \
	CI=${CONTEXT_INSTANCE}; \
	echo "## Registry: $${REGISTRY_HOST}" >&2; \
	if [[ "$${PUBLIC}" != "true" ]]; then \
		if [[ -n "$${HTTP_AUTH}" ]]; then \
			if [[ -f passwords.json ]]; then \
				USER=$$(jq -r --arg key "$${CI}" '.[$$key][0].username' passwords.json); \
				PASS=$$(jq -r --arg key "$${CI}" '.[$$key][0].password' passwords.json); \
			fi; \
			if [[ -z "$${USER}" || "$${USER}" == "null" ]]; then \
				USER=$$(echo "$${HTTP_AUTH}" | cut -d: -f1); \
				echo "Enter password for $${USER}@$${REGISTRY_HOST}:" >&2; \
				read -rs PASS; \
			fi; \
			CURL_OPTS="--user $${USER}:$${PASS}"; \
		elif [[ "$${MTLS_AUTH}" == "true" ]]; then \
			echo "Error: list-tags with mTLS auth is not implemented." >&2; exit 1; \
		fi; \
	fi; \
	repos=$$(curl -sf $${CURL_OPTS} https://$${REGISTRY_HOST}/v2/_catalog | jq -r '.repositories[]' 2>/dev/null); \
	if [[ -z "$${repos}" ]]; then echo "## No repositories found." >&2; exit 0; fi; \
	echo >&2; \
	for repo in $${repos}; do \
		tags=$$(curl -sf $${CURL_OPTS} https://$${REGISTRY_HOST}/v2/$${repo}/tags/list | jq -r '.tags[]' 2>/dev/null); \
		for tag in $${tags}; do \
			echo "$${REGISTRY_HOST}/$${repo}:$${tag}"; \
		done; \
	done; \
	echo >&2

.PHONY: delete-tags # Delete image tags from the registry
delete-tags:
	@if [[ ! -f ${ENV_FILE} ]]; then echo "Error: config file not found: ${ENV_FILE}" >&2; echo "Run 'make config' first." >&2; exit 1; fi; \
	REGISTRY_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get REGISTRY_TRAEFIK_HOST); \
	CI=${CONTEXT_INSTANCE}; \
	CURL_OPTS=""; \
	if [[ -f passwords.json ]]; then \
		USER=$$(jq -r --arg key "$${CI}" '.[$$key][0].username // empty' passwords.json 2>/dev/null); \
		PASS=$$(jq -r --arg key "$${CI}" '.[$$key][0].password // empty' passwords.json 2>/dev/null); \
	fi; \
	if [[ -z "$${USER}" || -z "$${PASS}" ]]; then \
		HTTP_AUTH=$$(${BIN}/dotenv -f ${ENV_FILE} get REGISTRY_HTTP_AUTH); \
		if [[ -n "$${HTTP_AUTH}" ]]; then \
			USER=$$(echo "$${HTTP_AUTH}" | cut -d: -f1); \
			echo "Enter password for $${USER}@$${REGISTRY_HOST}:" >&2; \
			read -rs PASS; \
		fi; \
	fi; \
	if [[ -n "$${USER}" && -n "$${PASS}" ]]; then \
		CURL_OPTS="--user $${USER}:$${PASS}"; \
	fi; \
	IMAGES=(); \
	repos=$$(curl -sf $${CURL_OPTS} https://$${REGISTRY_HOST}/v2/_catalog | jq -r '.repositories[]' 2>/dev/null); \
	if [[ -z "$${repos}" ]]; then echo "## No images found." >&2; exit 0; fi; \
	for repo in $${repos}; do \
		tags=$$(curl -sf $${CURL_OPTS} https://$${REGISTRY_HOST}/v2/$${repo}/tags/list | jq -r '.tags[]' 2>/dev/null); \
		for tag in $${tags}; do \
			IMAGES+=("$${repo}:$${tag}"); \
		done; \
	done; \
	if [[ $${#IMAGES[@]} -eq 0 ]]; then echo "## No images found." >&2; exit 0; fi; \
	SELECTED=$$(eval "${BIN}/script-wizard select 'Select images to delete:' $${IMAGES[@]@Q}"); \
	if [[ -z "$${SELECTED}" ]]; then echo "## No images selected." >&2; exit 0; fi; \
	echo >&2; \
	echo "## The following images will be deleted:" >&2; \
	for image in $${SELECTED}; do echo "##   $${image}" >&2; done; \
	echo >&2; \
	${BIN}/confirm no "Proceed with deletion" "?" || exit 0; \
	DELETED=0; \
	for image in $${SELECTED}; do \
		repo=$${image%%:*}; \
		tag=$${image##*:}; \
		digest=$$(curl -sf $${CURL_OPTS} \
			-H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
			-H "Accept: application/vnd.oci.image.manifest.v1+json" \
			--head https://$${REGISTRY_HOST}/v2/$${repo}/manifests/$${tag} \
			| grep -i docker-content-digest | awk '{print $$2}' | tr -d '\\r'); \
		if [[ -z "$${digest}" ]]; then \
			echo "## Error: could not get digest for $${image}" >&2; continue; \
		fi; \
		status=$$(curl -sf -o /dev/null -w '%{http_code}' $${CURL_OPTS} \
			-X DELETE https://$${REGISTRY_HOST}/v2/$${repo}/manifests/$${digest}); \
		if [[ "$${status}" == "202" ]]; then \
			echo "## Deleted $${image}" >&2; \
			DELETED=$$((DELETED + 1)); \
		else \
			echo "## Error deleting $${image} (HTTP $${status})" >&2; \
		fi; \
	done; \
	if [[ $${DELETED} -gt 0 ]]; then \
		echo >&2; \
		${BIN}/confirm yes "Run garbage collection (requires temporary registry restart)" "?" && make --no-print-directory garbage-collect || true; \
	fi

.PHONY: garbage-collect # Run garbage collection (requires temporary registry restart)
garbage-collect:
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="stop registry"
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="run --rm --entrypoint '' registry registry garbage-collect /etc/docker/registry/config.yml"
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="start registry"

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
