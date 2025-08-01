ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} OPENWEBUI_TRAEFIK_HOST "Enter the Open-WebUI domain name" openwebui${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} OPENWEBUI_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} OPENWEBUI
	@echo
	@echo "Enter the processing engine to use: cuda (for nvidia GPUs), rocm (for AMD GPUs), or cpu (to use only the CPU)."
	@${BIN}/reconfigure_compose_profiles_choose ${ENV_FILE} rocm="AMD GPU" cuda="Nvidia GPU" cpu="CPU only"
	@echo
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} OPENWEBUI_MODELS_HOST_PATH "If you want to save models in a specific directory on the host, enter the path here, or leave blank to save models to the Ollama container's named Docker volume."
	@echo
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get OPENWEBUI_EXPOSE_OLLAMA)" == 'false' && echo no || echo yes) "Do you want to expose Ollama to Traefik for use by external services" "?" && ( \
		${BIN}/reconfigure ${ENV_FILE} OPENWEBUI_EXPOSE_OLLAMA=true && \
		${BIN}/reconfigure_ask ${ENV_FILE} OPENWEBUI_OLLAMA_TRAEFIK_HOST "Enter the Ollama domain name" && \
		${BIN}/reconfigure_ask ${ENV_FILE} OPENWEBUI_OLLAMA_IP_SOURCERANGE "Enter the allowed client IP source range for the Ollama service (eg. 192.168.1.1/24 or 0.0.0.0/0)" \
	) || ( \
		${BIN}/reconfigure ${ENV_FILE} OPENWEBUI_EXPOSE_OLLAMA=false \
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:openwebui instance=@OPENWEBUI_INSTANCE traefik_host=@OPENWEBUI_TRAEFIK_HOST http_auth=OPENWEBUI_HTTP_AUTH http_auth_var=@OPENWEBUI_HTTP_AUTH ip_sourcerange=@OPENWEBUI_IP_SOURCERANGE oauth2=OPENWEBUI_OAUTH2 authorized_group=OPENWEBUI_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=OPENWEBUI_MTLS_AUTH mtls_authorized_certs=OPENWEBUI_MTLS_AUTHORIZED_CERTS models_host_path=OPENWEBUI_MODELS_HOST_PATH compose_profile=DOCKER_COMPOSE_PROFILES expose_ollama=OPENWEBUI_EXPOSE_OLLAMA ollama_ip_sourcerange=@OPENWEBUI_OLLAMA_IP_SOURCERANGE ollama_traefik_host=@OPENWEBUI_OLLAMA_TRAEFIK_HOST

.PHONY: shell
shell:
	@container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'openwebui' 'ollama-$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES)' --default 'openwebui'") && make --no-print-directory docker-compose-shell SERVICE=$${container}
