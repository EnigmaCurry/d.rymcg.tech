ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} NGINX_TRAEFIK_HOST "Enter the nginx domain name" www${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} NGINX_INSTANCE=$${instance:-default}
	@echo ""
#### Choose which docker-compose profiles to enable:
	@${BIN}/reconfigure_compose_profiles_select ${ENV_FILE} nginx="Base Nginx config (don't unselect this, it is required)" php-fpm="PHP script support + Redis session store" postgres="PostgreSQL database"
	@echo ""
#### Set the ngninx template depending on if php-fpm was enabled:
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep php-fpm >/dev/null && ${BIN}/reconfigure ${ENV_FILE} NGINX_TEMPLATE=php-fpm.template.conf || ${BIN}/reconfigure ${ENV_FILE} NGINX_TEMPLATE=default.template.conf
#### Set the postgres database password if postgres was enabled:
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep postgres >/dev/null && ${BIN}/reconfigure_password ${ENV_FILE} NGINX_POSTGRES_PASSWORD || true
#### Choose which PHP index file to install:
	@echo
	@echo "You have several choices of which PHP file to install at the root index:"
	@echo "default.php - this installs a simple 'Hello, World!' example."
	@echo "phpinfo.php - this installs a phpinfo() page."
	@echo "http://.../adminer.php - this installs the Adminer tool from github."
	@echo
	@${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES | sed 's/,/\n/g' | grep php-fpm >/dev/null && ${BIN}/reconfigure_choose ${ENV_FILE} NGINX_PHP_INDEX_FILE "Choose the index PHP file to install" "default.php" "phpinfo.php" "https://github.com/adminerevo/adminerevo/releases/download/v4.8.3/adminer-4.8.3.php" || true
#### Configure auth:
	@${BIN}/reconfigure_auth ${ENV_FILE} NGINX


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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:nginx instance=@NGINX_INSTANCE traefik_host=@NGINX_TRAEFIK_HOST http_auth=NGINX_HTTP_AUTH http_auth_var=@NGINX_HTTP_AUTH ip_sourcerange=@NGINX_IP_SOURCERANGE oauth2=NGINX_OAUTH2 authorized_group=NGINX_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=NGINX_MTLS_AUTH mtls_authorized_certs=NGINX_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=nginx

.PHONY: shell-php
shell-php:
	@make --no-print-directory docker-compose-shell SERVICE=php-fpm

.PHONY: shell-redis
shell-redis:
	@make --no-print-directory docker-compose-shell SERVICE=redis

.PHONY: compose-profiles
compose-profiles:
	@${BIN}/reconfigure_compose_profiles ${ENV_FILE} PROMETHEUS_NODE_EXPORTER_ENABLED=node-exporter PROMETHEUS_CADVISOR_ENABLED=cadvisor PROMETHEUS_ALERTMANAGER_ENABLED=alertmanager
