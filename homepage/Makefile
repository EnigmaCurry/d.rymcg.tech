ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} HOMEPAGE_TRAEFIK_HOST "Enter the homepage domain name" homepage${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} HOMEPAGE_WEBHOOK_HOST "Enter the separate webhook domain name" homepage-webhook${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@echo ""
	@${BIN}/reconfigure ${ENV_FILE} HOMEPAGE_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} HOMEPAGE
	@echo ""
	@${BIN}/reconfigure_password ${ENV_FILE} HOMEPAGE_RELOADER_HMAC_SECRET 45
	@echo
	@echo "HOMEPAGE_ALLOWED_HOSTS is required, and helps prevent certain kinds of attacks when retrieving data from the homepage API proxy. The value is a comma-separated (no spaces) list of allowed hosts (sometimes with the port) that can host your homepage install. For more information about where / how to set the variable, see https://gethomepage.dev/installation/#homepage_allowed_hosts ."
	@${BIN}/reconfigure_ask ${ENV_FILE} HOMEPAGE_ALLOWED_HOSTS "Enter the homepage domain name" $$(${BIN}/dotenv -f ${ENV_FILE} get HOMEPAGE_TRAEFIK_HOST)
	@echo
	@${BIN}/reconfigure ${ENV_FILE} HOMEPAGE_PUBLIC_HTTPS_PORT=$$([[ -z $$(${BIN}/dotenv -f ${ENV_FILE} get HOMEPAGE_PUBLIC_HTTPS_PORT) ]] && echo $$(${BIN}/dotenv -f ../${ROOT_ENV} get PUBLIC_HTTPS_PORT) || echo $$(${BIN}/dotenv -f ${ENV_FILE} get HOMEPAGE_PUBLIC_HTTPS_PORT))
	@echo ""
	@${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get HOMEPAGE_AUTO_CONFIG) == "true" ]] && echo "yes" || echo "no") "Do you want to auto-configure Homepage and to discover all of your running d.rymcg.tech apps of the current docker context" "?" && ${BIN}/reconfigure ${ENV_FILE} HOMEPAGE_AUTO_CONFIG=true && $(MAKE) autoconfig \
	|| ( ${BIN}/reconfigure ${ENV_FILE} HOMEPAGE_AUTO_CONFIG=false \
	&& echo "" && ${BIN}/reconfigure_ask ${ENV_FILE} HOMEPAGE_TEMPLATE_REPO "Enter the git repository used to make the config. All environment variables will be substituted in the templates via envsubst. Cloning from private git repositores is supported, but you must create a deploy key first." \
	&& echo "" && ${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get HOMEPAGE_TEMPLATE_REPO_SYNC_ON_START) == "true" ]] && echo "yes" || echo "no") "Do you want to reset your config on every startup from the HOMEPAGE_TEMPLATE_REPO? (Warning: ALL of your existing homepage config would be deleted every time the container restarts)" "?" && ${BIN}/reconfigure ${ENV_FILE} HOMEPAGE_TEMPLATE_REPO_SYNC_ON_START=true || ${BIN}/reconfigure ${ENV_FILE} HOMEPAGE_TEMPLATE_REPO_SYNC_ON_START=false )
	@echo ""

.PHONY: override-hook
override-hook: autoconfig
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:homepage instance=@HOMEPAGE_INSTANCE webhook_host=@HOMEPAGE_WEBHOOK_HOST traefik_host=@HOMEPAGE_TRAEFIK_HOST http_auth=HOMEPAGE_HTTP_AUTH http_auth_var=@HOMEPAGE_HTTP_AUTH ip_sourcerange=@HOMEPAGE_IP_SOURCERANGE enable_docker=HOMEPAGE_ENABLE_DOCKER reloader_path_prefix=HOMEPAGE_RELOADER_PATH_PREFIX oauth2=HOMEPAGE_OAUTH2 authorized_group=HOMEPAGE_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=HOMEPAGE_MTLS_AUTH mtls_authorized_certs=HOMEPAGE_MTLS_AUTHORIZED_CERTS extra_volumes=HOMEPAGE_EXTRA_VOLUMES

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=homepage

.PHONY: git-deploy-key # Create deploy key to clone your private config repo
git-deploy-key: override
	@docker compose --env-file ${ENV_FILE} --project-name=${PROJECT_NAME} -f docker-compose.yaml -f "docker-compose.override_${DOCKER_CONTEXT}_${INSTANCE}.yaml" run --rm -it homepage /bin/sh -c "mkdir -p /app/config/ssh/ && ssh-keygen -f /app/config/ssh/id_rsa -t rsa -P '' -C 'homepage-deploy-${DOCKER_CONTEXT}_${INSTANCE}'; (test -f /app/config/ssh/id_rsa.pub && echo '' && echo '# Public key fingerprint:' && ssh-keygen -lf /app/config/ssh/id_rsa.pub && echo '' && echo '# Public Deploy Key (Create this as a new deploy key in Forgejo repository settings):' && echo '' && cat /app/config/ssh/id_rsa.pub && echo '' || echo 'No public SSH key found.')"

.PHONY: autoconfig
autoconfig:
	@ROOT_DIR=${ROOT_DIR} DOCKER_CONTEXT=${DOCKER_CONTEXT} HOMEPAGE_ENABLE_DOCKER=${HOMEPAGE_ENABLE_DOCKER} ENV_FILE=${ENV_FILE} HOMEPAGE_AUTO_CONFIG="$$(${BIN}/dotenv -f ${ENV_FILE} get HOMEPAGE_AUTO_CONFIG)" ./homepage_autoconfig.sh
