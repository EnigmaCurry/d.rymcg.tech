ROOT_DIR = ..
STEP=step-cli
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} STEP_CA_TRAEFIK_HOST "Enter the step-ca domain name" ca${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} STEP_CA_PUBLIC_HTTPS_PORT=$$([[ -z $$(${BIN}/dotenv -f ${ENV_FILE} get STEP_CA_PUBLIC_HTTPS_PORT) ]] && echo $$(${BIN}/dotenv -f ../${ROOT_ENV} get PUBLIC_HTTPS_PORT) || echo $$(${BIN}/dotenv -f ${ENV_FILE} get STEP_CA_PUBLIC_HTTPS_PORT))
	@${BIN}/reconfigure ${ENV_FILE} STEP_CA_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} STEP_CA_AUTHORITY_POLICY_X509_ALLOW_DNS "Enter the list of allowed domain wildcards (comma separated)"
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:step-ca instance=@STEP_CA_INSTANCE traefik_host=@STEP_CA_TRAEFIK_HOST ip_sourcerange=@STEP_CA_IP_SOURCERANGE

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=step-ca

## TODO: Why does this print the wrong password?
# .PHONY: inspect-password # Retrieve the Step-CA password
# inspect-password:
# 	@make --no-print-directory docker-compose-shell SERVICE=step-ca COMMAND="cat /home/step/secrets/password" 2>/dev/null

.PHONY: inspect-fingerprint # Retrieve the Step-CA fingerprint
inspect-fingerprint:
	@make --no-print-directory docker-compose-shell SERVICE=step-ca COMMAND="step certificate fingerprint ~/certs/root_ca.crt" 2>/dev/null

.PHONY: inspect-config # Retrieve the Step-CA ca.json config file
inspect-config:
	@make --no-print-directory docker-compose-shell SERVICE=step-ca COMMAND="cat ~/config/ca.json" 2>/dev/null

.PHONY: client-bootstrap # Bootstrap the client's step-cli
client-bootstrap:
	@TRAEFIK_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get STEP_CA_TRAEFIK_HOST); STEP_CA_PUBLIC_HTTPS_PORT=$$(${BIN}/dotenv -f ${ENV_FILE} get STEP_CA_PUBLIC_HTTPS_PORT); FINGERPRINT=$$(make --no-print-directory inspect-fingerprint); echo "# CA Host: https://$${TRAEFIK_HOST}:$${STEP_CA_PUBLIC_HTTPS_PORT}"; echo "# CA Fingerprint: $${FINGERPRINT}"; ${STEP} ca bootstrap --ca-url "$${TRAEFIK_HOST}:$${STEP_CA_PUBLIC_HTTPS_PORT}" --fingerprint $${FINGERPRINT}

.PHONY: cert # Create certificate
cert:
	@CN=$$(${BIN}/ask_echo "Enter the subject (CN / domain name) to be certified"); ${STEP} ca certificate "$${CN}" "certs/$${CN}.crt" "certs/$${CN}.key" --not-after "$$(${BIN}/dotenv -f ${ENV_FILE} get STEP_CA_AUTHORITY_CLAIMS_DEFAULT_TLS_CERT_DURATION)" && ${STEP} certificate p12 "certs/$${CN}.p12" "certs/$${CN}.crt" "certs/$${CN}.key" && ${STEP} certificate inspect "certs/$${CN}.crt"

.PHONY: token # Make a temporary one time use API token
token:
	@CN=$$(${BIN}/ask_echo "Enter the subject (CN / domain name) for the token"); echo; ${STEP} ca token "$${CN}" --not-after 30m

.PHONY: inspect-ca-cert # Retrieve the Step-CA root CA certificate chain:
inspect-ca-cert:
	@make --no-print-directory docker-compose-shell SERVICE=step-ca COMMAND="step ca roots" 2>/dev/null

.PHONY: change-password # Change the managerial password for the root CA:
change-password:
	@echo
	@echo "## Note: after you confirm to proceed, this will ask you two questions:"
	@echo
	@echo "##  For question #1 enter the OLD password."
	@echo "##  For question #2 enter the NEW password."
	@echo
	@echo "## There will be NO confirmations after this point."
	@echo "## YOUR TYPING (or paste) MUST BE PERFECT!"
	@echo "## TAKE YOUR TIME, GET IT RIGHT!"
	@echo "## If in doubt, press Ctrl-C multiple times to abort."
	@echo
	@${BIN}/confirm no "This will change the root CA passphrase. Did you read all the above" "?"
	@echo ""
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="cp script/change_password.sh step-ca:/tmp/change_password.sh"
	@make --no-print-directory docker-compose-shell SERVICE=step-ca COMMAND="/bin/bash /tmp/change_password.sh"

.PHONY: enable-acme # Enable the ACME server
enable-acme:
	@${BIN}/confirm no "This will enable the ACME server"
	@echo ""
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="cp script/enable_acme.sh step-ca:/tmp/enable_acme.sh"
	@make --no-print-directory docker-compose-shell SERVICE=step-ca COMMAND="/bin/bash /tmp/enable_acme.sh"

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
