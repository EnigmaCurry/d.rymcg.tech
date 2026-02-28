ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} OPENBAO_TRAEFIK_HOST "Enter the OpenBao domain name" bao${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} OPENBAO_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} OPENBAO
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:openbao instance=@OPENBAO_INSTANCE traefik_host=@OPENBAO_TRAEFIK_HOST http_auth=OPENBAO_HTTP_AUTH http_auth_var=@OPENBAO_HTTP_AUTH ip_sourcerange=@OPENBAO_IP_SOURCERANGE oauth2=OPENBAO_OAUTH2 authorized_group=OPENBAO_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=OPENBAO_MTLS_AUTH mtls_authorized_certs=OPENBAO_MTLS_AUTHORIZED_CERTS

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=openbao

.PHONY: init # Initialize OpenBao (shows unseal keys and root token)
init:
	@make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="bao operator init"

.PHONY: unseal # Unseal OpenBao (interactive - enter unseal keys)
unseal:
	@make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="bao operator unseal"

.PHONY: seal-status # Show OpenBao seal status
seal-status:
	@make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="bao status"

.PHONY: enable-ssh-engine # Enable SSH secrets engine at ssh-client-signer
enable-ssh-engine:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="sh -c 'export BAO_TOKEN=$${BAO_TOKEN} && bao secrets enable -path=ssh-client-signer ssh'"

.PHONY: configure-ssh-ca # Generate SSH CA signing key
configure-ssh-ca:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="sh -c 'export BAO_TOKEN=$${BAO_TOKEN} && bao write ssh-client-signer/config/ca generate_signing_key=true'"

.PHONY: get-ssh-ca-public-key # Output the SSH CA public key (for server TrustedUserCAKeys)
get-ssh-ca-public-key:
	@make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="cat /openbao/data/ssh-client-signer-ca-public-key" 2>/dev/null || \
	echo "Run 'make configure-ssh-ca' first to generate the CA key." >&2; \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="sh -c 'export BAO_TOKEN=$${BAO_TOKEN} && curl -s http://127.0.0.1:8200/v1/ssh-client-signer/public_key'"

.PHONY: create-ssh-role # Create SSH signing role (woodpecker-short-lived, 15m TTL, ed25519)
create-ssh-role:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="sh -c 'export BAO_TOKEN=$${BAO_TOKEN} && bao write ssh-client-signer/roles/woodpecker-short-lived - <<ROLE_EOF\n{\"allow_user_certificates\": true, \"allowed_users\": \"*\", \"default_extensions\": {\"permit-pty\": \"\"}, \"key_type\": \"ca\", \"default_user\": \"root\", \"ttl\": \"15m\", \"max_ttl\": \"30m\", \"algorithm_signer\": \"default\"}\nROLE_EOF'"

.PHONY: enable-approle # Enable AppRole auth method
enable-approle:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="sh -c 'export BAO_TOKEN=$${BAO_TOKEN} && bao auth enable approle'"

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
