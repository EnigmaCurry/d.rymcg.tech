ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} LEANTIME_TRAEFIK_HOST "Enter the Leantime domain name" leantime${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} LEANTIME_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} LEANTIME
	@${BIN}/reconfigure_password ${ENV_FILE} LEANTIME_MYSQL_ROOT_PASSWORD 45
	@${BIN}/reconfigure_password ${ENV_FILE} LEANTIME_MYSQL_PASSWORD 45
	@${BIN}/reconfigure_password ${ENV_FILE} LEANTIME_SESSION_PASSWORD 45
	@echo
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get LEANTIME_EMAIL_USE_SMTP)" == 'false' && echo no || echo yes) "Configure an SMTP server for Leantime to send emails" "?" && ( \
		${BIN}/reconfigure ${ENV_FILE} LEANTIME_EMAIL_USE_SMTP=true && \
		${BIN}/reconfigure_ask ${ENV_FILE} LEANTIME_EMAIL_SMTP_HOSTS "Enter the SMTP server hostname" && \
		${BIN}/reconfigure_ask ${ENV_FILE} LEANTIME_EMAIL_SMTP_PORT "Enter the SMTP server port" 465 && \
		${BIN}/reconfigure_ask ${ENV_FILE} LEANTIME_EMAIL_SMTP_USERNAME "Enter the SMTP server login" && \
		${BIN}/reconfigure_ask ${ENV_FILE} LEANTIME_EMAIL_SMTP_PASSWORD "Enter the SMTP server password" && \
		${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get LEANTIME_EMAIL_SMTP_AUTO_TLS)" == 'true' && echo yes || echo no) "Does the SMTP server use TLS" "?" && ${BIN}/reconfigure ${ENV_FILE} LEANTIME_EMAIL_SMTP_AUTO_TLS=true || ${BIN}/reconfigure ${ENV_FILE} LEANTIME_EMAIL_SMTP_AUTO_TLS=false && \
		${BIN}/reconfigure_choose ${ENV_FILE} LEANTIME_EMAIL_SMTP_SECURE 'SMTP Security protocol' 'TLS' 'SSL' 'STARTTLS' \
	) || ${BIN}/reconfigure ${ENV_FILE} LEANTIME_EMAIL_USE_SMTP=false
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} LEANTIME_EMAIL_RETURN "What email address should Leantime system emails be from"
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:leantime instance=@LEANTIME_INSTANCE traefik_host=@LEANTIME_TRAEFIK_HOST http_auth=LEANTIME_HTTP_AUTH http_auth_var=@LEANTIME_HTTP_AUTH ip_sourcerange=@LEANTIME_IP_SOURCERANGE oauth2=LEANTIME_OAUTH2 authorized_group=LEANTIME_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=LEANTIME_MTLS_AUTH mtls_authorized_certs=LEANTIME_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'leantime' 'leantime-db' --default 'leantime'") && make --no-print-directory docker-compose-shell SERVICE=$${container}

.PHONY: init # Run Leantime's installation script and create the admin user
init:
	@export DOCKER_CONTEXT=${DOCKER_CONTEXT}; export ENV_FILE=${ENV_FILE}; export CONTEXT_INSTANCE=${CONTEXT_INSTANCE}; ${BIN}/open /install