ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} COMFYUI_TRAEFIK_HOST "Enter the comfyui domain name" comfyui${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} COMFYUI_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} COMFYUI
	@echo
	@echo "Enter the processing engine to use: cuda (for nvidia GPUs), rocm (for AMD GPUs), intel (for Intel GPUs), or cpu (for CPU only)."
	@${BIN}/reconfigure_compose_profiles_choose ${ENV_FILE} rocm="AMD GPU" cuda="Nvidia GPU" intel="Intel GPU" cpu="CPU only"
	@echo
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} COMFYUI_MODELS_HOST_PATH "If you want to save models in a specific directory on the host, enter the absolute path here, or leave blank to save models to the ComfyUI container's named Docker volume."
	@echo
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} COMFYUI_OUTPUT_HOST_PATH "If you want to save output files (e.g., images, video, audio) in a specific directory on the host, enter the absolute path here, or leave blank to save them to the ComfyUI container's named Docker volume. NOTE: This path on the host should be different than the path you use for the models."
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:comfyui instance=@COMFYUI_INSTANCE traefik_host=@COMFYUI_TRAEFIK_HOST http_auth=COMFYUI_HTTP_AUTH http_auth_var=@COMFYUI_HTTP_AUTH ip_sourcerange=@COMFYUI_IP_SOURCERANGE oauth2=COMFYUI_OAUTH2 authorized_group=COMFYUI_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=COMFYUI_MTLS_AUTH mtls_authorized_certs=COMFYUI_MTLS_AUTHORIZED_CERTS compose_profile=DOCKER_COMPOSE_PROFILES models_host_path=COMFYUI_MODELS_HOST_PATH output_host_path=COMFYUI_OUTPUT_HOST_PATH

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=comfyui-$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES)

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo

.PHONY: add-model # Add a model from a URL into ComfyUI
add-model:
	@choices="audio_encoders checkpoints clip clip_vision configs controlnet diffusers diffusion_models embeddings gligen hypernetworks loras model_patches photomaker style_models text_encoders unet upscale_models vae vae_approx"; \
	model_type=$$("${BIN}/script-wizard" choose "What type of model are you installing?" $$choices --default "checkpoints"); \
	model_url=$$("${BIN}/ask_echo" "What is the download URL of the model?" ""); \
	basename=$$(basename "$${model_url}" | cut -d'?' -f1); \
	docker exec -it "comfyui-comfyui-$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES)-1" bash -c "cd /ComfyUI/models/$${model_type} && wget $${model_url} -O $${basename}"

.PHONY: remove-model # Permanently delete a model from ComfyUI
remove-model:
	@choices="audio_encoders checkpoints clip clip_vision configs controlnet diffusers diffusion_models embeddings gligen hypernetworks loras model_patches photomaker style_models text_encoders unet upscale_models vae vae_approx"; \
	model_type=$$("${BIN}/script-wizard" choose "What type of model are you removing?" $$choices --default "checkpoints"); \
	models=$$(docker exec "comfyui-comfyui-$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES)-1" ls /ComfyUI/models/$${model_type} 2>/dev/null); \
	if [ -z "$${models}" ]; then \
		echo "No models found in /ComfyUI/models/$${model_type}\n"; \
		exit 0; \
	fi; \
	selected_model=$$("${BIN}/script-wizard" choose "Which model do you want to remove?" $$models); \
	if [ -n "$${selected_model}" ]; then \
		echo "Removing /ComfyUI/models/$${model_type}/$${selected_model}"; \
docker exec -it "comfyui-comfyui-$$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES)-1" rm -rf "/ComfyUI/models/$${model_type}/$${selected_model}"; \
	else \
		echo "No model selected, operation cancelled."; \
	fi
