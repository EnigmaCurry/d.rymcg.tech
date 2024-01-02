ROOT_DIR = ${CREATE_TEMPLATE_ROOT_DIR}
VIRTUALENV_DIR=$(shell realpath virtualenv)

include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} ${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_TRAEFIK_HOST "Enter the ${CREATE_TEMPLATE_PROJECT_NAME} domain name" ${CREATE_TEMPLATE_PROJECT_URL_NAME}${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} ${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} ${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}
	@[[ -z "$$(${BIN}/dotenv -f ${ENV_FILE} get ${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_POSTGRES_PASSWORD)" ]] && ${BIN}/reconfigure ${ENV_FILE} ${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_POSTGRES_PASSWORD=$$(openssl rand -base64 45) || true
	@echo ""

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:${CREATE_TEMPLATE_PROJECT_NAME} instance=@${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_INSTANCE traefik_host=@${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_TRAEFIK_HOST http_auth=${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_HTTP_AUTH http_auth_var=@${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_HTTP_AUTH ip_sourcerange=@${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_IP_SOURCERANGE oauth2=${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_OAUTH2 authorized_group=${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_OAUTH2_AUTHORIZED_GROUP development_mode=${CREATE_TEMPLATE_PROJECT_NAME_UPPERCASE}_DEVELOPMENT_MODE

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=${CREATE_TEMPLATE_PROJECT_NAME}

.PHONY: dev-sync
dev-sync:
	@${BIN}/dev-sync ${CREATE_TEMPLATE_PROJECT_NAME}_development flask

.PHONY: localdb # Open BASH shell with remote DB connection through SSH
localdb:
	@${BIN}/postgresql-tunnel ${ENV_FILE} database ${INSTANCE}




###
### Local non-docker python development inside virtualenv:
###

.PHONY: local-check-deps
local-check-deps:
	${BIN}/check_deps python3

.PHONY: local-install # Creates a virtual environment and install all dependencies
local-install: local-check-deps
	python3 -m venv ${VIRTUALENV_DIR}
	${VIRTUALENV_DIR}/bin/python -m pip install --upgrade pip
	${VIRTUALENV_DIR}/bin/pip install -r api/requirements/requirements.txt -r api/requirements/dev.requirements.txt

.PHONY: local-dev # Starts localhost development server
local-dev:
	PYTHONPATH=$(shell realpath api) API_LOG_LEVEL=debug API_DB=development.sqlite3 ${VIRTUALENV_DIR}/bin/python -m app

.PHONY: local-dev-public # Starts public development server on all network interfaces (0.0.0.0)
local-dev-public:
	API_HTTP_HOST=0.0.0.0 ${MAKE} dev

.PHONY: local-prod # Starts production server
local-prod:
	API_DEPLOYMENT=prod API_DB=prod.sqlite3 ${VIRTUALENV_DIR}/bin/python app.py

.PHONY: local-clean # Deletes the virtual environment
local-clean:
	rm -rf ${VIRTUALENV_DIR}

.PHONY: local-activate # Enters a sub-shell with the virtualenv activated
local-activate:
	$${SHELL} --rcfile <(echo "source ${VIRTUALENV_DIR}/bin/activate")

.PHONY: local-test # Runs tests
local-test:
	${VIRTUALENV_DIR}/bin/python -m pytest --doctest-modules --ignore=_stuff

.PHONY: local-upgrade # Upgrades Python package versions in requirements files
local-upgrade:
	${VIRTUALENV_DIR}/bin/python -m pur -r api/requirements/requirements.txt -r api/requirements/dev.requirements.txt
