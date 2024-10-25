ROOT_DIR = ~/git/vendor/enigmacurry/d.rymcg.tech

include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} GRADIO_TRAEFIK_HOST "Enter the gradio domain name" gradio${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} GRADIO_INSTANCE=$${instance:-default}
	@echo
	@${BIN}/reconfigure_choose ${ENV_FILE} GRADIO_APP "Choose the gradio app to install" $$(find ./gradio -maxdepth 1 -mindepth 1 -type d | xargs -iXX basename XX)

	@GRADIO_APP=$$(${BIN}/dotenv -f ${ENV_FILE} get GRADIO_APP); \
	case $$GRADIO_APP in \
		"chatbot") \
			echo "Installing chatbot app"; \
			${BIN}/reconfigure_ask "${ENV_FILE}" GRADIO_CHATBOT_API "Enter the lm-studio API URL" "http://127.0.0.1:1234/v1/chat/completions"; \
			${BIN}/reconfigure_ask "${ENV_FILE}" GRADIO_CHATBOT_MODELS "Enter the comma separated list of chat models" "codestral-22b-v0.1,gemma-2-27b-it"; \
			;; \
		*) \
			echo "Installing app: $$GRADIO_APP"; \
			;; \
	esac

	@echo
	@${BIN}/reconfigure_auth ${ENV_FILE} GRADIO
	@echo ""

config-chatbot:
	@${BIN}/reconfigure_ask ${ENV_FILE} GRADIO_CHATBOT_API "Enter the remote chatbot URL" http://127.0.0.1:1234/v1/chat/completions

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:gradio instance=@GRADIO_INSTANCE traefik_host=@GRADIO_TRAEFIK_HOST http_auth=GRADIO_HTTP_AUTH http_auth_var=@GRADIO_HTTP_AUTH ip_sourcerange=@GRADIO_IP_SOURCERANGE oauth2=GRADIO_OAUTH2 authorized_group=GRADIO_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=GRADIO_MTLS_AUTH mtls_authorized_certs=GRADIO_MTLS_AUTHORIZED_CERTS app=GRADIO_APP chatbot_api=GRADIO_CHATBOT_API log_level=GRADIO_LOG_LEVEL chatbot_models=GRADIO_CHATBOT_MODELS traefik_entrypoint=GRADIO_TRAEFIK_ENTRYPOINT

.PHONY: shell # Enter shell of api container (or set service=name to enter a different one)
shell:
	@make --no-print-directory docker-compose-shell SERVICE=gradio

dev:
	@if ! command -v cargo-watch &> /dev/null; then \
		echo "Installing cargo-watch..."; \
		cargo install cargo-watch; \
	fi
	cargo watch -s 'sleep 5 &&  make up'
