ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} ACME_SH_ACME_CA "Enter the CA ACME host"
	@${BIN}/reconfigure ${ENV_FILE} ACME_SH_INSTANCE=$${instance:-default}
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:acme_sh instance=@ACME_SH_INSTANCE traefik_host=@ACME_SH_TRAEFIK_HOST http_auth=ACME_SH_HTTP_AUTH http_auth_var=@ACME_SH_HTTP_AUTH ip_sourcerange=@ACME_SH_IP_SOURCERANGE oauth2=ACME_SH_OAUTH2 authorized_group=ACME_SH_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=ACME_SH_MTLS_AUTH mtls_authorized_certs=ACME_SH_MTLS_AUTHORIZED_CERTS

.PHONY: build-hook-pre
build-hook-pre:
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="build base-image"

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=cron

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo

.PHONY: update-cron-schedule
update-cron-schedule:
	@SCHEDULE="$$(${BIN}/dotenv -f ${ENV_FILE} get ACME_SH_CRON_SCHEDULE)"; make --no-print-directory docker-compose-shell SERVICE=cron COMMAND="crontab -l"

.PHONY: trust-ca-cert
trust-ca-cert:
	@make --no-print-directory docker-compose-shell SERVICE=cron COMMAND="test -f /acme.sh/root_ca.pem || curl -ko /acme.sh/root_ca.pem https://$$(${BIN}/dotenv -f ${ENV_FILE} get ACME_SH_ACME_CA)/roots.pem; apk add --no-cache ca-certificates && cp /acme.sh/root_ca.pem /usr/local/share/ca-certificates/root_ca.pem && update-ca-certificates && echo Added Root CA certificate to system trust store: && cat /usr/local/share/ca-certificates/root_ca.pem && echo && echo Fingerprint: && openssl x509 -in /usr/local/share/ca-certificates/root_ca.pem -outform der | openssl dgst -sha256 && echo && echo You should verify that this fingerprint matches your actual CA server."

.PHONY: register
register: trust-ca-cert
	@make --no-print-directory docker-compose-shell SERVICE=cron COMMAND="acme.sh --register-account --server https://$$(${BIN}/dotenv -f ${ENV_FILE} get ACME_SH_ACME_CA)$$(${BIN}/dotenv -f ${ENV_FILE} get ACME_SH_ACME_DIRECTORY) --ca-bundle /acme.sh/root_ca.pem"

.PHONY: cert
cert:
	BIN=${BIN} ENV_FILE=${ENV_FILE} ./script/create_cert.sh
