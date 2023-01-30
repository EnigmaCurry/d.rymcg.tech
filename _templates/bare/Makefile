## ROOT_DIR is the full path to the git clone of d.rymcg.tech:
ROOT_DIR = ${CREATE_TEMPLATE_ROOT_DIR}
## This Makefile inherits abilities from d.rymcg.tech Makefiles
include ${ROOT_DIR}/_scripts/Makefile.projects-external
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	## config-hook is for the custom configuration the user must enter when running `make config`:
	# reconfigure_ask will ask the user to enter the value for a variable, with the given prompt, with the given default value, and save it to the env file:
	@${BIN}/reconfigure_ask ${ENV_FILE} ${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_TRAEFIK_HOST "Enter the ${CREATE_TEMPLATE_PROJECT_NAME} domain name" ${CREATE_TEMPLATE_PROJECT_URL_NAME}${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	# reconfigure will directly set a value in the env file:
	@${BIN}/reconfigure ${ENV_FILE} ${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_INSTANCE=$${instance:-default}
	# configure IP filter:
	@${BIN}/reconfigure_ask ${ENV_FILE} ${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_IP_SOURCERANGE "Enter the client IP Address range filter (CIDR)" 0.0.0.0/0
	# Configure HTTP Auth:
	@(${BIN}/confirm $$(test -n "$$(${BIN}/dotenv -f ${ENV_FILE} get ${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_HTTP_AUTH)" && echo yes || echo no) "Do you want to enable HTTP Basic Authentication" "?" && ${BIN}/reconfigure_htpasswd ${ENV_FILE} ${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_HTTP_AUTH) || ${BIN}/reconfigure ${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_HTTP_AUTH=''


.PHONY: override-hook
override-hook:
	@${BIN}/docker_compose_override ${ENV_FILE} project=:${CREATE_TEMPLATE_PROJECT_NAME} context=:"${DOCKER_CONTEXT}" instance=${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_INSTANCE traefik_host_var=:${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_TRAEFIK_HOST http_auth=${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_HTTP_AUTH http_auth_var=:${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_HTTP_AUTH ip_sourcerange_var=:${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_IP_SOURCERANGE development_mode=${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_DEVELOPMENT_MODE
