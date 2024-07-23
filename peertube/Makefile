ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} PEERTUBE_TRAEFIK_HOST "Enter the Peertube domain name" peertube${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} PEERTUBE_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} PEERTUBE
	@${BIN}/reconfigure_password ${ENV_FILE} PEERTUBE_SECRET 32
	@${BIN}/reconfigure_password ${ENV_FILE} PEERTUBE_POSTGRES_PASSWORD 45
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} PEERTUBE_ADMIN_EMAIL "Enter an email address for the Peertube admin user" admin@$$(${BIN}/dotenv -f ${ENV_FILE} get PEERTUBE_TRAEFIK_HOST)
	@${BIN}/reconfigure_ask ${ENV_FILE} PEERTUBE_SMTP_FROM "Enter an admin email address to be used as the \"From\" address" noreply@$$(${BIN}/dotenv -f ${ENV_FILE} get PEERTUBE_TRAEFIK_HOST)
	@echo
	@echo "You can configure Peertube to send emails via a custom SMTP server that you configure or via the Postfix service installed with Peertube."
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get PEERTUBE_SMTP_HOSTNAME)" == 'postfix' && echo no || echo yes) "Do you want Peertube to send emails from a custom SMTP server" "?" && ( \
		${BIN}/reconfigure_ask ${ENV_FILE} PEERTUBE_SMTP_HOSTNAME "Enter the SMTP server hostname" && \
		${BIN}/reconfigure_ask ${ENV_FILE} PEERTUBE_SMTP_PORT "Enter the SMTP server port" 25 && \
		${BIN}/reconfigure_ask ${ENV_FILE} PEERTUBE_SMTP_USERNAME "Enter the SMTP server login" && \
		${BIN}/reconfigure_ask ${ENV_FILE} PEERTUBE_SMTP_PASSWORD "Enter the SMTP server password" && \
		${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get PEERTUBE_SMTP_TLS)" == 'true' && echo yes || echo no) "Does the SMTP server use TLS" "?" && ${BIN}/reconfigure ${ENV_FILE} PEERTUBE_SMTP_TLS=true || ${BIN}/reconfigure ${ENV_FILE} PEERTUBE_SMTP_TLS=false && \
		${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get PEERTUBE_SMTP_DISABLE_STARTTLS)" == 'true' && echo yes || echo no) "Disable STARTTLS" "?" && ${BIN}/reconfigure ${ENV_FILE} PEERTUBE_SMTP_DISABLE_STARTTLS=true || ${BIN}/reconfigure ${ENV_FILE} PEERTUBE_SMTP_DISABLE_STARTTLS=false \
	) || ( \
		${BIN}/reconfigure ${ENV_FILE} PEERTUBE_SMTP_HOSTNAME=postfix && \
		${BIN}/reconfigure ${ENV_FILE} PEERTUBE_SMTP_PORT=25 && \
		${BIN}/reconfigure ${ENV_FILE} PEERTUBE_SMTP_TLS=false && \
		${BIN}/reconfigure ${ENV_FILE} PEERTUBE_SMTP_DISABLE_STARTTLS=false && \
		echo && echo "Postfix configuration:" && \
		${BIN}/reconfigure_ask ${ENV_FILE} PEERTUBE_POSTFIX_myhostname "Enter the domain of your email address" && \
		# I use `dotenv set` in the next line instead of `reconfigure` because the value needs to have an "=" in it but `reconfigure` strips all "=" \
		${BIN}/dotenv -f ${ENV_FILE} set PEERTUBE_OPENDKIM_DOMAINS="$$(${BIN}/dotenv -f ${ENV_FILE} get PEERTUBE_POSTFIX_myhostname)=postfix" && echo "Set PEERTUBE_OPENDKIM_DOMAINS=$$(${BIN}/dotenv -f ${ENV_FILE} get PEERTUBE_POSTFIX_MYHOSTNAME)=postfix" && \
		echo "*" && echo "* If you need to customize DKIM, manually edit \`${ENV_FILE}\` and enter appropriate values for the DKIM variables." && echo "*" \
	)
	@echo
	@${BIN}/reconfigure_choose ${ENV_FILE} PEERTUBE_LIVESTREAMING "You can enable livestreaming via RTMP or RTMPS. Choose livestreaming status:" "Disabled" "RTMP" "RTMPS"
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:peertube instance=@PEERTUBE_INSTANCE traefik_host=@PEERTUBE_TRAEFIK_HOST http_auth=PEERTUBE_HTTP_AUTH http_auth_var=@PEERTUBE_HTTP_AUTH ip_sourcerange=@PEERTUBE_IP_SOURCERANGE oauth2=PEERTUBE_OAUTH2 authorized_group=PEERTUBE_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=PEERTUBE_MTLS_AUTH mtls_authorized_certs=PEERTUBE_MTLS_AUTHORIZED_CERTS livestreaming=PEERTUBE_LIVESTREAMING

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=peertube
