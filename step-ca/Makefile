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

.PHONY: client-bootstrap
client-bootstrap:
	@TRAEFIK_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get STEP_CA_TRAEFIK_HOST); FINGERPRINT=$$(make --no-print-directory inspect-fingerprint); echo "# CA Host: https://$${TRAEFIK_HOST}"; echo "# CA Fingerprint: $${FINGERPRINT}"; ${STEP} ca bootstrap --ca-url "$${TRAEFIK_HOST}" --fingerprint $${FINGERPRINT}

.PHONY: client-cert
client-cert:
	@DOMAIN=$$(${BIN}/ask_echo "Enter the domain name to be certified"); ${STEP} ca certificate "$${DOMAIN}" "certs/$${DOMAIN}.crt" "certs/$${DOMAIN}.key" && ${STEP} certificate inspect "certs/$${DOMAIN}.crt"

