ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} GLANCES_TRAEFIK_HOST "Enter the glances domain name" glances${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} GLANCES_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} GLANCES
	@echo
	@${BIN}/confirm no "Do you want to enable Nvidia GPU support" "?" && ${BIN}/reconfigure ${ENV_FILE} GLANCES_GPU=true || ${BIN}/reconfigure ${ENV_FILE} GLANCES_GPU=false
	@echo
	@echo "Glances can report on container metrics if you allow it access to the host's Docker socket. Be aware that allowing access to the Docker socket is not safe because it effectively grants full control over the Docker daemon, enabling a container or attacker to escalate privileges, manipulate containers, and potentially compromise the host system."
	@${BIN}/confirm $$("$$(${BIN}/dotenv -f ${ENV_FILE} get GLANCES_CONTAINER_METRICS)" == "false" && echo 'yes' || echo 'no') "Do you want to enable container metrics" "?" && ${BIN}/reconfigure ${ENV_FILE} GLANCES_CONTAINER_METRICS=true || ${BIN}/reconfigure ${ENV_FILE} GLANCES_CONTAINER_METRICS=false
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:glances instance=@GLANCES_INSTANCE traefik_host=@GLANCES_TRAEFIK_HOST http_auth=GLANCES_HTTP_AUTH http_auth_var=@GLANCES_HTTP_AUTH ip_sourcerange=@GLANCES_IP_SOURCERANGE oauth2=GLANCES_OAUTH2 authorized_group=GLANCES_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=GLANCES_MTLS_AUTH mtls_authorized_certs=GLANCES_MTLS_AUTHORIZED_CERTS gpu_support=GLANCES_GPU container_metrics=GLANCES_CONTAINER_METRICS

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=glances
