## ROOT_DIR is the full path to the git clone of d.rymcg.tech:
ROOT_DIR = ${CREATE_TEMPLATE_ROOT_DIR}
## This Makefile inherits abilities from d.rymcg.tech Makefiles
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	## config-hook is for the custom configuration the user must enter when running `make config`:
	# reconfigure_ask will ask the user to enter the value for a variable, with the given prompt, with the given default value, and save it to the env file:
	@${BIN}/reconfigure_ask ${ENV_FILE} ${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_TRAEFIK_HOST "Enter the ${CREATE_TEMPLATE_PROJECT_NAME} domain name" ${CREATE_TEMPLATE_PROJECT_URL_NAME}${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	# reconfigure will directly set a value in the env file
	@${BIN}/reconfigure ${ENV_FILE} ${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_INSTANCE=$${instance:-default}
