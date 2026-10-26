ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
	@${BIN}/reconfigure_ask ${ENV_FILE} CRYPTPAD_TRAEFIK_HOST "Enter the main cryptpad domain name" pad${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} CRYPTPAD_SANDBOX_HOST "Enter the sandbox domain name" pad-sandbox${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} CRYPTPAD_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} CRYPTPAD
	@${BIN}/reconfigure_choose ${ENV_FILE} CRYPTPAD_INSTALL_ONLYOFFICE "Install the office editors (Document, Sheet, Presentation apps) on first startup? (Euro-Office, an OnlyOffice-based fork; downloads ~2-4GB.)" "yes" "no"
	@${BIN}/reconfigure_ask_email_address ${ENV_FILE} CRYPTPAD_ADMIN_EMAIL "Enter the admin contact email address shown on the contact page (can be changed later in the admin panel)" admin@example.com

.PHONY: override-hook
override-hook:
#### This sets the override template variables for docker-compose.instance.yaml:
	@${BIN}/docker_compose_override ${ENV_FILE} project=:cryptpad instance=@CRYPTPAD_INSTANCE traefik_host=@CRYPTPAD_TRAEFIK_HOST sandbox_host=@CRYPTPAD_SANDBOX_HOST http_auth=CRYPTPAD_HTTP_AUTH http_auth_var=@CRYPTPAD_HTTP_AUTH ip_sourcerange=@CRYPTPAD_IP_SOURCERANGE oauth2=CRYPTPAD_OAUTH2 authorized_group=CRYPTPAD_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=CRYPTPAD_MTLS_AUTH mtls_authorized_certs=CRYPTPAD_MTLS_AUTHORIZED_CERTS homepage_labels_enable=CRYPTPAD_HOMEPAGE_LABELS_ENABLE homepage_group_cryptpad=CRYPTPAD_HOMEPAGE_GROUP_CRYPTPAD homepage_name_cryptpad=CRYPTPAD_HOMEPAGE_NAME_CRYPTPAD homepage_icon_cryptpad=CRYPTPAD_HOMEPAGE_ICON_CRYPTPAD homepage_description_cryptpad=CRYPTPAD_HOMEPAGE_DESCRIPTION_CRYPTPAD homepage_show_stats_cryptpad=CRYPTPAD_HOMEPAGE_SHOW_STATS_CRYPTPAD

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=cryptpad

.PHONY: install-hook-pre
install-hook-pre:
	@echo

.PHONY: install-hook
install-hook:
	@echo
	@echo "If this is the first time you're starting this instance, check the logs for"
	@echo "the instance setup URL, then visit it in your browser to create your first"
	@echo "admin account and customize the instance:"
	@echo
	@echo "  make logs-out service=cryptpad"
	@echo
