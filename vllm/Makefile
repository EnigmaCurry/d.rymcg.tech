ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} VLLM_TRAEFIK_HOST "Enter the vLLM domain name" vllm${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} VLLM_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} VLLM
	@echo ""
	@echo "Enter the processing engine to use: cuda (for nvidia GPUs) or rocm (for AMD GPUs)."
	@${BIN}/reconfigure_compose_profiles_choose ${ENV_FILE} cuda="Nvidia GPU" rocm="AMD GPU"
	@echo ""
	@${BIN}/reconfigure_ask ${ENV_FILE} VLLM_GIT_REPO "Enter the vLLM git repository URL" https://github.com/vllm-project/vllm.git
	@${BIN}/reconfigure_ask ${ENV_FILE} VLLM_GIT_REF "Enter the git branch or tag to build" main
	@echo ""
	@${BIN}/reconfigure_ask ${ENV_FILE} VLLM_MODEL "Enter the HuggingFace model to serve" Qwen/Qwen3-0.6B
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} VLLM_MAX_MODEL_LEN "Enter the maximum context length (leave blank for model default)"
	@echo ""
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} VLLM_HF_TOKEN "Enter your HuggingFace token for gated/private models (leave blank for public models)"
	@echo ""
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} VLLM_MODELS_HOST_PATH "If you want to save models in a specific directory on the host, enter the path here, or leave blank to save models to the vLLM container's named Docker volume."
	@echo
	@${BIN}/confirm $$(test -n "$$(${BIN}/dotenv -f ${ENV_FILE} get VLLM_API_TOKEN)" && echo yes || echo no) "Do you want to require an API token to access this service" "?" && ( \
	    ${BIN}/reconfigure_password ${ENV_FILE} VLLM_API_TOKEN 45 \
	) || ( \
	    ${BIN}/reconfigure ${ENV_FILE} "VLLM_API_TOKEN=" \
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:vllm instance=@VLLM_INSTANCE traefik_host=@VLLM_TRAEFIK_HOST http_auth=VLLM_HTTP_AUTH http_auth_var=@VLLM_HTTP_AUTH ip_sourcerange=@VLLM_IP_SOURCERANGE oauth2=VLLM_OAUTH2 authorized_group=VLLM_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=VLLM_MTLS_AUTH mtls_authorized_certs=VLLM_MTLS_AUTHORIZED_CERTS models_host_path=VLLM_MODELS_HOST_PATH compose_profile=DOCKER_COMPOSE_PROFILES api_token=VLLM_API_TOKEN model=VLLM_MODEL max_model_len=VLLM_MAX_MODEL_LEN hf_token=VLLM_HF_TOKEN trust_remote_code=VLLM_TRUST_REMOTE_CODE enable_auto_tool_choice=VLLM_ENABLE_AUTO_TOOL_CHOICE tool_call_parser=VLLM_TOOL_CALL_PARSER

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=vllm-$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES)

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@VLLM_GIT_REPO=$$(${BIN}/dotenv -f ${ENV_FILE} get VLLM_GIT_REPO); \
	VLLM_GIT_REF=$$(${BIN}/dotenv -f ${ENV_FILE} get VLLM_GIT_REF); \
	if [ -d vllm-src/.git ]; then \
		echo "Updating vllm-src from $${VLLM_GIT_REPO} ref $${VLLM_GIT_REF} ..."; \
		git -C vllm-src fetch origin; \
		git -C vllm-src checkout $${VLLM_GIT_REF}; \
		git -C vllm-src pull --ff-only origin $${VLLM_GIT_REF} 2>/dev/null || true; \
	else \
		echo "Cloning vllm-src from $${VLLM_GIT_REPO} ref $${VLLM_GIT_REF} ..."; \
		git clone --branch $${VLLM_GIT_REF} $${VLLM_GIT_REPO} vllm-src; \
	fi
