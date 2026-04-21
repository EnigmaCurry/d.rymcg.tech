ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} LLAMA_TRAEFIK_HOST "Enter the llama.cpp domain name" llama${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} LLAMA_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} LLAMA
	@echo ""
	@echo "Enter the processing engine to use: cuda (for nvidia GPUs), rocm (for AMD GPUs), or cpu (to use only the CPU)."
	@${BIN}/reconfigure_compose_profiles_choose ${ENV_FILE} rocm="AMD GPU" cuda="Nvidia GPU" cpu="CPU only"
	@echo ""
	@if [[ "$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES)" == "rocm" ]]; then \
	    echo "If your GPU isn't officially supported by ROCm, you can set LLAMA_HSA_OVERRIDE_GFX_VERSION to a value that matches your GPU's architecture (e.g., \"10.3.0\"). Leave blank if your GPU is supported by ROCm."; \
		ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} LLAMA_HSA_OVERRIDE_GFX_VERSION "Enter your AMD GPU's architecture version" ; \
		echo ""; \
	else \
		${BIN}/reconfigure ${ENV_FILE} "LLAMA_HSA_OVERRIDE_GFX_VERSION="; \
	fi
	@${BIN}/reconfigure_choose ${ENV_FILE} LLAMA_IMAGE_VARIANT "Select the image variant:" server full light
	@echo ""
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} LLAMA_MODELS_HOST_PATH "If you want to save models in a specific directory on the host, enter the path here, or leave blank to save models to the llama.cpp container's named Docker volume."
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} LLAMA_SERVER_PORT "Enter the internal server port for llama-server" 8080
	@echo
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} LLAMA_INITIAL_MODEL "Enter the path to the initial model to load at startup (inside container, e.g., /models/model.gguf), or leave blank to switch between models on the fly via the web UI or API."
	@echo
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} LLAMA_N_GPU_LAYERS "Enter the number of layers to offload to GPU (leave blank for auto-detection, or set to 99 for all layers)."
	@echo
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} LLAMA_CONTEXT_LENGTH "Enter the context length (leave blank for model default)."
	@echo
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} LLAMA_MODELS_MAX "Enter the maximum number of models loaded simultaneously (LRU eviction, 0 for unlimited, default 4)." 4
	@echo
	@${BIN}/confirm $$(test -n "$$(${BIN}/dotenv -f ${ENV_FILE} get LLAMA_API_TOKEN)" && echo yes || echo no) "Do you want to require an API token to access this service" "?" && ( \
	    ${BIN}/reconfigure_password ${ENV_FILE} LLAMA_API_TOKEN 45 \
	) || ( \
	    ${BIN}/reconfigure ${ENV_FILE} "LLAMA_API_TOKEN=" \
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:llama instance=@LLAMA_INSTANCE traefik_host=@LLAMA_TRAEFIK_HOST http_auth=LLAMA_HTTP_AUTH http_auth_var=@LLAMA_HTTP_AUTH ip_sourcerange=@LLAMA_IP_SOURCERANGE oauth2=LLAMA_OAUTH2 authorized_group=LLAMA_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=LLAMA_MTLS_AUTH mtls_authorized_certs=LLAMA_MTLS_AUTHORIZED_CERTS models_host_path=LLAMA_MODELS_HOST_PATH compose_profile=DOCKER_COMPOSE_PROFILES api_token=LLAMA_API_TOKEN server_port=LLAMA_SERVER_PORT initial_model=LLAMA_INITIAL_MODEL n_gpu_layers=LLAMA_N_GPU_LAYERS context_length=LLAMA_CONTEXT_LENGTH image_variant=LLAMA_IMAGE_VARIANT models_max=LLAMA_MODELS_MAX jinja=LLAMA_JINJA

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=llama-$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES)

.PHONY: add-models # Download models from HuggingFace or direct URLs
add-models:
	@${ROOT_DIR}/llama-cpp/llama-add-models llama-$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES) $$(${BIN}/dotenv -f ${ENV_FILE} get LLAMA_HF_TOKEN) ${ENV_FILE} $$(${BIN}/dotenv -f ${ENV_FILE} get LLAMA_SERVER_PORT) $$(${BIN}/dotenv -f ${ENV_FILE} get LLAMA_API_TOKEN)

.PHONY: list-models # List all models in /models/ (simple list)
list-models:
	@${ROOT_DIR}/llama-cpp/llama-list-models llama-$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES) ${ENV_FILE}

.PHONY: list-models-json # List all models in /models/ (JSON output)
list-models-json:
	@${ROOT_DIR}/llama-cpp/llama-list-models --json llama-$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES) ${ENV_FILE}

.PHONY: delete-models # Delete selected models from /models/
delete-models:
	@${ROOT_DIR}/llama-cpp/llama-delete-models llama-$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES) ${ENV_FILE} $$(${BIN}/dotenv -f ${ENV_FILE} get LLAMA_SERVER_PORT) $$(${BIN}/dotenv -f ${ENV_FILE} get LLAMA_API_TOKEN)

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
