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
	@KEY_SHARES=$$(${BIN}/dotenv -f ${ENV_FILE} get OPENBAO_KEY_SHARES); \
	KEY_THRESHOLD=$$(${BIN}/dotenv -f ${ENV_FILE} get OPENBAO_KEY_THRESHOLD); \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="bao operator init -key-shares=$${KEY_SHARES:-1} -key-threshold=$${KEY_THRESHOLD:-1}"

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
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="BAO_TOKEN=$${BAO_TOKEN} bao secrets enable -path=ssh-client-signer ssh"

.PHONY: configure-ssh-ca # Generate SSH CA signing key
configure-ssh-ca:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="BAO_TOKEN=$${BAO_TOKEN} bao write ssh-client-signer/config/ca generate_signing_key=true"

.PHONY: get-ssh-ca-public-key # Output the SSH CA public key (for server TrustedUserCAKeys)
get-ssh-ca-public-key:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="BAO_TOKEN=$${BAO_TOKEN} bao read -field=public_key ssh-client-signer/config/ca"

.PHONY: create-ssh-role # Create SSH signing role (woodpecker-short-lived, 15m TTL, ed25519)
create-ssh-role:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="echo eyJhbGxvd191c2VyX2NlcnRpZmljYXRlcyI6dHJ1ZSwiYWxsb3dlZF91c2VycyI6IioiLCJkZWZhdWx0X2V4dGVuc2lvbnMiOnsicGVybWl0LXB0eSI6IiJ9LCJrZXlfdHlwZSI6ImNhIiwiZGVmYXVsdF91c2VyIjoicm9vdCIsInR0bCI6IjE1bSIsIm1heF90dGwiOiIzMG0iLCJhbGdvcml0aG1fc2lnbmVyIjoiZGVmYXVsdCJ9 | base64 -d | BAO_TOKEN=$${BAO_TOKEN} bao write ssh-client-signer/roles/woodpecker-short-lived -"

.PHONY: read-ssh-role # Read the SSH signing role configuration
read-ssh-role:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="BAO_TOKEN=$${BAO_TOKEN} bao read ssh-client-signer/roles/woodpecker-short-lived"

.PHONY: enable-kv # Enable KV v2 secrets engine
enable-kv:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="BAO_TOKEN=$${BAO_TOKEN} bao secrets enable -version=2 -path=secret kv"

.PHONY: put-age-key # Store an AGE secret key (usage: make put-age-key path=sops/mykey)
put-age-key:
	@if [ -z "$${path}" ]; then echo "ERROR: path is required (e.g., make put-age-key path=sops/d2-admin/myserver-production)" >&2; exit 1; fi; \
	echo "Storing AGE key at: secret/$${path}"; \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	echo "Enter the AGE secret key (AGE-SECRET-KEY-...):"; \
	read -rs AGE_KEY; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="BAO_TOKEN=$${BAO_TOKEN} bao kv put secret/$${path} key=$${AGE_KEY}"

.PHONY: get-age-key # Read a stored AGE key (usage: make get-age-key path=sops/mykey)
get-age-key:
	@if [ -z "$${path}" ]; then echo "ERROR: path is required (e.g., make get-age-key path=sops/d2-admin/myserver-production)" >&2; exit 1; fi; \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="BAO_TOKEN=$${BAO_TOKEN} bao kv get secret/$${path}"

.PHONY: list-age-keys # List all stored AGE keys under sops/
list-age-keys:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="BAO_TOKEN=$${BAO_TOKEN} bao kv list secret/sops"

.PHONY: delete-age-key # Delete a stored AGE key (usage: make delete-age-key path=sops/mykey)
delete-age-key:
	@if [ -z "$${path}" ]; then echo "ERROR: path is required (e.g., make delete-age-key path=sops/d2-admin/myserver-production)" >&2; exit 1; fi; \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="BAO_TOKEN=$${BAO_TOKEN} bao kv metadata delete secret/$${path}"

.PHONY: enable-approle # Enable AppRole auth method
enable-approle:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="BAO_TOKEN=$${BAO_TOKEN} bao auth enable approle"

.PHONY: create-policy # Create a deploy repo policy (usage: make create-policy repo=d2-admin)
create-policy:
	@if [ -z "$${repo}" ]; then echo "ERROR: repo is required (e.g., make create-policy repo=d2-admin)" >&2; exit 1; fi; \
	echo "Creating policy: $${repo}-deploy (read sops/$${repo}/*, sign SSH keys)"; \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	POLICY=$$(printf 'path "secret/data/sops/%s/*" {\n  capabilities = ["read"]\n}\n\npath "ssh-client-signer/sign/woodpecker-short-lived" {\n  capabilities = ["create", "update"]\n}' "$${repo}" | base64 -w0); \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="echo $${POLICY} | base64 -d | BAO_TOKEN=$${BAO_TOKEN} bao policy write $${repo}-deploy -"

.PHONY: create-approle # Create an AppRole for a deploy repo (usage: make create-approle repo=d2-admin)
create-approle:
	@if [ -z "$${repo}" ]; then echo "ERROR: repo is required (e.g., make create-approle repo=d2-admin)" >&2; exit 1; fi; \
	echo "Creating AppRole: $${repo}-deploy (policy: $${repo}-deploy, 20m TTL)"; \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	ROLE=$$(printf '{"token_policies":"%s-deploy","token_ttl":"20m","token_max_ttl":"30m","secret_id_ttl":"0"}' "$${repo}" | base64 -w0); \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="echo $${ROLE} | base64 -d | BAO_TOKEN=$${BAO_TOKEN} bao write auth/approle/role/$${repo}-deploy -"

.PHONY: get-role-id # Get an AppRole role ID (usage: make get-role-id repo=d2-admin)
get-role-id:
	@if [ -z "$${repo}" ]; then echo "ERROR: repo is required (e.g., make get-role-id repo=d2-admin)" >&2; exit 1; fi; \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="BAO_TOKEN=$${BAO_TOKEN} bao read -field=role_id auth/approle/role/$${repo}-deploy/role-id"

.PHONY: generate-secret-id # Generate an AppRole secret ID (usage: make generate-secret-id repo=d2-admin)
generate-secret-id:
	@if [ -z "$${repo}" ]; then echo "ERROR: repo is required (e.g., make generate-secret-id repo=d2-admin)" >&2; exit 1; fi; \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; \
	make --no-print-directory docker-compose-shell SERVICE=openbao COMMAND="BAO_TOKEN=$${BAO_TOKEN} bao write -field=secret_id -f auth/approle/role/$${repo}-deploy/secret-id"

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
