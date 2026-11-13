ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} PL_MAIL_TRAEFIK_HOST "Enter the plMail domain name" mail${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} PL_MAIL_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} PL_MAIL
	#### APP_PUBLIC_URL = traefik host + PUBLIC_HTTPS_PORT (forgejo pattern;
	#### omit the port when it is 443):
	@PUBLIC_HTTPS_PORT="$$(${BIN}/dotenv -f ${ROOT_DIR}/${ROOT_ENV} get PUBLIC_HTTPS_PORT)"; if [[ -n "$${PUBLIC_HTTPS_PORT}" && "$${PUBLIC_HTTPS_PORT}" != "443" ]]; then ${BIN}/reconfigure ${ENV_FILE} "PL_MAIL_APP_PUBLIC_URL=https://$$(${BIN}/dotenv -f ${ENV_FILE} get PL_MAIL_TRAEFIK_HOST):$${PUBLIC_HTTPS_PORT}"; else ${BIN}/reconfigure ${ENV_FILE} "PL_MAIL_APP_PUBLIC_URL=https://$$(${BIN}/dotenv -f ${ENV_FILE} get PL_MAIL_TRAEFIK_HOST)"; fi
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} PL_MAIL_OIDC_ISSUER "OpenID Connect issuer URL (blank to disable SSO)" ""
	@if [[ -n "$$(${BIN}/dotenv -f ${ENV_FILE} get PL_MAIL_OIDC_ISSUER)" ]]; then \
		${BIN}/reconfigure_ask ${ENV_FILE} PL_MAIL_OIDC_CLIENT_ID "OpenID Connect client id" "" && \
		${BIN}/reconfigure_ask ${ENV_FILE} PL_MAIL_OIDC_CLIENT_SECRET "OpenID Connect client secret" ""; \
	fi
	@echo ""
	@echo "After 'make install', open $$(${BIN}/dotenv -f ${ENV_FILE} get PL_MAIL_APP_PUBLIC_URL) and create"
	@echo "the first admin account on the /install page, then add your IMAP/Gmail/Outlook"
	@echo "mailbox under Settings -> Mail accounts."
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:pl-mail instance=@PL_MAIL_INSTANCE traefik_host=@PL_MAIL_TRAEFIK_HOST http_auth=PL_MAIL_HTTP_AUTH http_auth_var=@PL_MAIL_HTTP_AUTH ip_sourcerange=@PL_MAIL_IP_SOURCERANGE oauth2=PL_MAIL_OAUTH2 authorized_group=PL_MAIL_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=PL_MAIL_MTLS_AUTH mtls_authorized_certs=PL_MAIL_MTLS_AUTHORIZED_CERTS homepage_labels_enable=PL_MAIL_HOMEPAGE_LABELS_ENABLE homepage_group_pl_mail=PL_MAIL_HOMEPAGE_GROUP_PL_MAIL homepage_name_pl_mail=PL_MAIL_HOMEPAGE_NAME_PL_MAIL homepage_icon_pl_mail=PL_MAIL_HOMEPAGE_ICON_PL_MAIL homepage_description_pl_mail=PL_MAIL_HOMEPAGE_DESCRIPTION_PL_MAIL homepage_show_stats_pl_mail=PL_MAIL_HOMEPAGE_SHOW_STATS_PL_MAIL

.PHONY: shell
shell:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'php' 'worker' 'database' --default 'php'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: install-hook
install-hook:
	@echo
	@echo "Next steps:"
	@echo "  1. Open $$(${BIN}/dotenv -f ${ENV_FILE} get PL_MAIL_APP_PUBLIC_URL) in your browser."
	@echo "  2. Create the first admin account on the /install page, right away:"
	@echo "     until the first account exists, anyone who reaches that URL becomes admin."
	@echo "  3. Add your IMAP/Gmail/Outlook mailbox under Settings -> Mail accounts."
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
