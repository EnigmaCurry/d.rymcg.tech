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
	@echo ""
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get OPENWEBUI_CUSTOM_CSS)" == 'true' && echo yes || echo no) "Do want to add your own custom.css file" "?" && ( \
		${BIN}/reconfigure ${ENV_FILE} OPENWEBUI_CUSTOM_CSS=true && \
		touch custom.css && \
		echo -e "\nName your custom CSS file \`custom.css\` and move it to this project directory before running `make install`." \
	) || ( \
		${BIN}/reconfigure ${ENV_FILE} OPENWEBUI_CUSTOM_CSS=false \
	)
	@echo ""
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get OPENWEBUI_OLLAMA_ENABLE)" == 'false' && echo no || echo yes) "Do you want to install Ollama" "?" && ( \
		${BIN}/reconfigure ${ENV_FILE} OPENWEBUI_OLLAMA_ENABLE=true && \
		echo "" && \
		echo "Enter the processing engine to use: cuda (for nvidia GPUs), rocm (for AMD GPUs), or cpu (to use only the CPU)." && \
		${BIN}/reconfigure_compose_profiles_choose ${ENV_FILE} rocm="AMD GPU" cuda="Nvidia GPU" cpu="CPU only" && \
		echo "" && \
		if [[ "$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES)" == "rocm" ]]; then \
	    	echo "If your GPU isn't officially supported by ROCm, you can set OPENWEBUI_OLLAMA_HSA_OVERRIDE_GFX_VERSION to a value that matches your GPU’s architecture (e.g., \"10.3.0\"). Leave blank if your GPU is supported by ROCm."; \
			ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} OPENWEBUI_OLLAMA_HSA_OVERRIDE_GFX_VERSION "Enter your AMD GPU's architecture version"; \
		else \
			${BIN}/reconfigure ${ENV_FILE} "OPENWEBUI_OLLAMA_HSA_OVERRIDE_GFX_VERSION="; \
		fi && \
		echo "" && \
		ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} OPENWEBUI_MODELS_HOST_PATH "If you want to save models in a specific directory on the host, enter the path here, or leave blank to save models to the Ollama container's named Docker volume." \
	) || ( \
		${BIN}/reconfigure ${ENV_FILE} OPENWEBUI_OLLAMA_ENABLE=false && \
		${BIN}/reconfigure ${ENV_FILE} DOCKER_COMPOSE_PROFILES=default \
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:openwebui instance=@OPENWEBUI_INSTANCE traefik_host=@OPENWEBUI_TRAEFIK_HOST http_auth=OPENWEBUI_HTTP_AUTH http_auth_var=@OPENWEBUI_HTTP_AUTH ip_sourcerange=@OPENWEBUI_IP_SOURCERANGE oauth2=OPENWEBUI_OAUTH2 authorized_group=OPENWEBUI_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=OPENWEBUI_MTLS_AUTH mtls_authorized_certs=OPENWEBUI_MTLS_AUTHORIZED_CERTS models_host_path=OPENWEBUI_MODELS_HOST_PATH compose_profile=DOCKER_COMPOSE_PROFILES enable_ollama=OPENWEBUI_OLLAMA_ENABLE homepage_labels_enable=OPENWEBUI_HOMEPAGE_LABELS_ENABLE homepage_group_openwebui=OPENWEBUI_HOMEPAGE_GROUP_OPENWEBUI homepage_name_openwebui=OPENWEBUI_HOMEPAGE_NAME_OPENWEBUI homepage_icon_openwebui=OPENWEBUI_HOMEPAGE_ICON_OPENWEBUI homepage_description_openwebui=OPENWEBUI_HOMEPAGE_DESCRIPTION_OPENWEBUI homepage_show_stats_openwebui=OPENWEBUI_HOMEPAGE_SHOW_STATS_OPENWEBUI

.PHONY: shell
shell:
	@if [ -z "$(service)" ]; then \
		if [[ "$$(${BIN}/dotenv -f ${ENV_FILE} get OPENWEBUI_OLLAMA_ENABLE)" == "true" ]]; then \
			container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'openwebui' 'ollama-$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES)' --default 'openwebui'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
		else \
			make --no-print-directory docker-compose-shell SERVICE=openwebui; \
		fi \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: install-hook
install-hook:
	@if [[ "$$(${BIN}/dotenv -f ${ENV_FILE} get OPENWEBUI_CUSTOM_CSS)" == "true" ]]; then \
		if [[ -f custom.css ]]; then \
			if [[ "${INSTANCE}" == "default" ]]; then \
				CONTAINER_NAME="open-webui-openwebui-1"; \
			else \
				CONTAINER_NAME="open-webui_${INSTANCE}-openwebui-1"; \
			fi; \
			docker cp custom.css "$${CONTAINER_NAME}":/app/build/static/custom.css; \
		else \
			echo -e "\nNo \`custom.css\` file found in \`$$(pwd)/\`."; \
		fi \
	fi
	@echo
	@echo "Restarting container so Open-WebUI recognizes updated \`custom.css\`."
	@echo
	@make restart

.PHONY: install-hook-pre
install-hook-pre:
	@echo
