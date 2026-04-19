ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} TTS_STORY_TRAEFIK_HOST "Enter the tts-story domain name" tts-story${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} TTS_STORY_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} TTS_STORY_GIT_REPO "Enter the git repository URL" https://github.com/EnigmaCurry/TTS-Story.git
	@${BIN}/reconfigure_ask ${ENV_FILE} TTS_STORY_GIT_BRANCH "Enter the git branch to build" docker
	@${BIN}/reconfigure_ask ${ENV_FILE} TTS_STORY_GPU_TYPE "Enter GPU type (nvidia, rocm, or cpu)" cpu
	@${BIN}/reconfigure_auth ${ENV_FILE} TTS_STORY

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:tts-story instance=@TTS_STORY_INSTANCE traefik_host=@TTS_STORY_TRAEFIK_HOST http_auth=TTS_STORY_HTTP_AUTH http_auth_var=@TTS_STORY_HTTP_AUTH ip_sourcerange=@TTS_STORY_IP_SOURCERANGE oauth2=TTS_STORY_OAUTH2 authorized_group=TTS_STORY_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=TTS_STORY_MTLS_AUTH mtls_authorized_certs=TTS_STORY_MTLS_AUTHORIZED_CERTS gpu_type=TTS_STORY_GPU_TYPE

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=tts-story

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
