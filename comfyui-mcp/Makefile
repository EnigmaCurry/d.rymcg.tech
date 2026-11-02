ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} COMFYUI_MCP_TRAEFIK_HOST "Enter the comfyui-mcp domain name" comfyui-mcp${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} COMFYUI_MCP_INSTANCE=$${instance:-default}
	@echo
	@echo "This service drives an existing ComfyUI deployment. It connects to the"
	@echo "ComfyUI container over that project's Docker network, so ComfyUI must"
	@echo "already be installed on this same Docker context."
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} COMFYUI_MCP_COMFYUI_NETWORK "Enter the ComfyUI project's Docker network name" comfyui_default
	@${BIN}/reconfigure_ask ${ENV_FILE} COMFYUI_MCP_COMFYUI_URL "Enter the ComfyUI base URL (service name on that network)" http://comfyui-cuda:8188
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} COMFYUI_MCP_CHECKPOINT "Enter the SDXL checkpoint filename to generate with" albedobaseXL_v21.safetensors
	@${BIN}/reconfigure_ask ${ENV_FILE} COMFYUI_MCP_LORA "Enter the pixel art LoRA filename" pixel-art-xl.safetensors
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} COMFYUI_MCP_EDIT_MODEL "Enter the instruction-edit model filename (used by refine_pixel_art)" qwen_image_edit_2509_fp8_e4m3fn.safetensors
	@${BIN}/reconfigure_ask ${ENV_FILE} COMFYUI_MCP_EDIT_TEXT_ENCODER "Enter the edit model text encoder filename" qwen_2.5_vl_7b_fp8_scaled.safetensors
	@${BIN}/reconfigure_ask ${ENV_FILE} COMFYUI_MCP_EDIT_VAE "Enter the edit model VAE filename" qwen_image_vae.safetensors
	@echo
	@${BIN}/confirm $$(test -n "$$(${BIN}/dotenv -f ${ENV_FILE} get COMFYUI_MCP_API_TOKEN)" && echo yes || echo yes) "Do you want to require an API token to access this MCP endpoint" "?" && ( \
	    ${BIN}/reconfigure_password ${ENV_FILE} COMFYUI_MCP_API_TOKEN 45 \
	) || ( \
	    ${BIN}/reconfigure ${ENV_FILE} "COMFYUI_MCP_API_TOKEN=" \
	)
	@echo
	@${BIN}/reconfigure_auth ${ENV_FILE} COMFYUI_MCP
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:comfyui-mcp instance=@COMFYUI_MCP_INSTANCE traefik_host=@COMFYUI_MCP_TRAEFIK_HOST http_auth=COMFYUI_MCP_HTTP_AUTH http_auth_var=@COMFYUI_MCP_HTTP_AUTH ip_sourcerange=@COMFYUI_MCP_IP_SOURCERANGE oauth2=COMFYUI_MCP_OAUTH2 authorized_group=COMFYUI_MCP_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=COMFYUI_MCP_MTLS_AUTH mtls_authorized_certs=COMFYUI_MCP_MTLS_AUTHORIZED_CERTS

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=comfyui-mcp

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo

.PHONY: url # Print the MCP endpoint URL to give to your MCP client
url:
	@echo "https://$$(${BIN}/dotenv -f ${ENV_FILE} get COMFYUI_MCP_TRAEFIK_HOST)$$(${BIN}/dotenv -f ${ENV_FILE} get COMFYUI_MCP_PATH)"
