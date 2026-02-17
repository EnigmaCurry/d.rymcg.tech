ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} INVOKEAI_TRAEFIK_HOST "Enter the invokeai domain name" invokeai${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} INVOKEAI_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} INVOKEAI
	@echo
	@${BIN}/reconfigure_compose_profiles_choose ${ENV_FILE} cuda="Nvidia GPU" rocm="AMD GPU" cpu="CPU Only"
	@${BIN}/reconfigure ${ENV_FILE} INVOKEAI_GPU_DRIVER=$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES)
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES) == "rocm" ]] && \
		( \
			output=$$(ssh ${DOCKER_CONTEXT} "getent group render") && \
			gid=$$(printf '%s\n' "$$output" | awk -F: '{print $$3}') && \
			${BIN}/reconfigure ${ENV_FILE} INVOKEAI_RENDER_GROUP_ID=$$gid; \
		) || \
		true;
	@echo
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get INVOKEAI_STORE_MODELS_SEPARATELY)" == 'false' && echo no || echo yes) "By default, InvokeAI stores its models in the Docker volume with the rest of its data. Do you want to store models in a separate directory on the host (bind-mounted into the container)" "?" && ( \
		${BIN}/reconfigure ${ENV_FILE} INVOKEAI_STORE_MODELS_SEPARATELY=true && \
		${BIN}/reconfigure_ask_validate_regex ${ENV_FILE} INVOKEAI_SEPARATE_MODELS_HOST_PATH "Enter an absolute path on the host that you want InvokeAI to store models in" - "^\/^\/$$|^~$$|^(\/|~\/)(([^\/]+\/)*[^\/]+)?\/?$$" \
	) || ( \
		${BIN}/reconfigure ${ENV_FILE} INVOKEAI_STORE_MODELS_SEPARATELY=false \
	)
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:invokeai instance=@INVOKEAI_INSTANCE traefik_host=@INVOKEAI_TRAEFIK_HOST http_auth=INVOKEAI_HTTP_AUTH http_auth_var=@INVOKEAI_HTTP_AUTH ip_sourcerange=@INVOKEAI_IP_SOURCERANGE oauth2=INVOKEAI_OAUTH2 authorized_group=INVOKEAI_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=INVOKEAI_MTLS_AUTH mtls_authorized_certs=INVOKEAI_MTLS_AUTHORIZED_CERTS docker_compose_profiles=DOCKER_COMPOSE_PROFILES store_models_separately=INVOKEAI_STORE_MODELS_SEPARATELY host_path=INVOKEAI_SEPARATE_MODELS_HOST_PATH traefik_entrypoint=INVOKEAI_TRAEFIK_ENTRYPOINT

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=invokeai-$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES)

.PHONY: get-render-gid # Show the GID of the "render" group on the host
get-render-gid:
	@output=$$(ssh ${DOCKER_CONTEXT} "getent group render") && \
		gid=$$(printf '%s\n' "$$output" | awk -F: '{print $$3}') && \
		echo "GID for \"render\" group on host: $$gid"


.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
