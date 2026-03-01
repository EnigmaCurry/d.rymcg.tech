ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

## NOTE: Never pass BAO_TOKEN (or other secrets) as part of the command string
## or in COMMAND= arguments. Use `export BAO_TOKEN` + `exec -e BAO_TOKEN` so
## the token is passed via the process environment and never visible in ps
## output, docker logs, or make's command echo.

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
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; bao secrets enable -path=ssh-client-signer ssh; echo; echo'"

.PHONY: configure-ssh-ca # Generate SSH CA signing key
configure-ssh-ca:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; bao write ssh-client-signer/config/ca generate_signing_key=true; echo; echo'"

.PHONY: get-ssh-ca-public-key # Output the SSH CA public key (for server TrustedUserCAKeys)
get-ssh-ca-public-key:
	@TRAEFIK_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get OPENBAO_TRAEFIK_HOST); \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; echo \"## $${TRAEFIK_HOST} SSH CA Public Key\"; bao read -field=public_key ssh-client-signer/config/ca; echo; echo'"

.PHONY: create-ssh-role # Create SSH signing role (woodpecker-short-lived, 15m TTL, ed25519)
create-ssh-role:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; echo eyJhbGxvd191c2VyX2NlcnRpZmljYXRlcyI6dHJ1ZSwiYWxsb3dlZF91c2VycyI6IioiLCJkZWZhdWx0X2V4dGVuc2lvbnMiOnsicGVybWl0LXB0eSI6IiJ9LCJrZXlfdHlwZSI6ImNhIiwiZGVmYXVsdF91c2VyIjoicm9vdCIsInR0bCI6IjE1bSIsIm1heF90dGwiOiIzMG0iLCJhbGdvcml0aG1fc2lnbmVyIjoiZGVmYXVsdCJ9 | base64 -d | bao write ssh-client-signer/roles/woodpecker-short-lived -; echo; echo'"

.PHONY: read-ssh-role # Read the SSH signing role configuration
read-ssh-role:
	@TRAEFIK_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get OPENBAO_TRAEFIK_HOST); \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; echo \"## $${TRAEFIK_HOST} SSH Role: woodpecker-short-lived\"; bao read ssh-client-signer/roles/woodpecker-short-lived; echo; echo'"

.PHONY: enable-kv # Enable KV v2 secrets engine
enable-kv:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; bao secrets enable -version=2 -path=secret kv; echo; echo'"

.PHONY: put-age-key # Store an AGE secret key (usage: make put-age-key path=sops/mykey)
put-age-key:
	@if [ -z "$${path}" ]; then echo "ERROR: path is required (e.g., make put-age-key path=sops/d2-admin/myserver-production)" >&2; exit 1; fi; \
	echo "Storing AGE key at: secret/$${path}"; \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	echo "Enter the AGE secret key (AGE-SECRET-KEY-...):"; \
	read -rs BAO_AGE_KEY; export BAO_AGE_KEY; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -e BAO_AGE_KEY -T openbao /bin/sh -c 'echo; bao kv put secret/$${path} key=$${BAO_AGE_KEY}; echo; echo'"

.PHONY: get-age-key # Read a stored AGE key (usage: make get-age-key path=sops/mykey)
get-age-key:
	@if [ -z "$${path}" ]; then echo "ERROR: path is required (e.g., make get-age-key path=sops/d2-admin/myserver-production)" >&2; exit 1; fi; \
	TRAEFIK_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get OPENBAO_TRAEFIK_HOST); \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; echo \"## $${TRAEFIK_HOST} AGE Key: $${path}\"; bao kv get secret/$${path}; echo; echo'"

.PHONY: list-age-keys # List all stored AGE keys under sops/
list-age-keys:
	@TRAEFIK_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get OPENBAO_TRAEFIK_HOST); \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; echo \"## $${TRAEFIK_HOST} AGE Keys\"; bao kv list secret/sops; echo; echo'"

.PHONY: delete-age-key # Delete a stored AGE key (usage: make delete-age-key path=sops/mykey)
delete-age-key:
	@if [ -z "$${path}" ]; then echo "ERROR: path is required (e.g., make delete-age-key path=sops/d2-admin/myserver-production)" >&2; exit 1; fi; \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; bao kv metadata delete secret/$${path}; echo; echo'"

.PHONY: enable-approle # Enable AppRole auth method
enable-approle:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; bao auth enable approle; echo; echo'"

.PHONY: disable-approle # Disable AppRole auth method
disable-approle:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; bao auth disable approle; echo; echo'"

.PHONY: list-approles # List all AppRoles
list-approles:
	@TRAEFIK_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get OPENBAO_TRAEFIK_HOST); \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; echo \"## $${TRAEFIK_HOST} AppRoles\"; bao list auth/approle/role; echo; echo'"

.PHONY: delete-approles # Delete AppRoles (interactive selection)
delete-approles:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	ROLES=$$(make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao bao list -format=json auth/approle/role" 2>/dev/null | jq -r '.[]'); \
	if [ -z "$${ROLES}" ]; then echo ""; echo "No AppRoles found."; echo; echo; exit 0; fi; \
	readarray -t ROLE_ARRAY <<< "$${ROLES}"; \
	readarray -t SELECTED < <(${BIN}/script-wizard select "Select AppRoles to delete" "$${ROLE_ARRAY[@]}"); \
	if [ $${#SELECTED[@]} -eq 0 ]; then echo ""; echo "No AppRoles selected."; echo; echo; exit 0; fi; \
	echo; \
	for role in "$${SELECTED[@]}"; do \
		echo "Deleting AppRole: $${role}"; \
		make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao bao delete auth/approle/role/$${role}" 2>/dev/null; \
	done; \
	echo; echo

.PHONY: list-policies # List all policies
list-policies:
	@TRAEFIK_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get OPENBAO_TRAEFIK_HOST); \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; echo \"## $${TRAEFIK_HOST} Policies\"; bao policy list; echo; echo'"

.PHONY: delete-policies # Delete policies (interactive selection)
delete-policies:
	@echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	POLICIES=$$(make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao bao policy list -format=json" 2>/dev/null | jq -r '.[]' | grep -vxE 'default|root'); \
	if [ -z "$${POLICIES}" ]; then echo ""; echo "No deletable policies found."; echo; echo; exit 0; fi; \
	readarray -t POLICY_ARRAY <<< "$${POLICIES}"; \
	readarray -t SELECTED < <(${BIN}/script-wizard select "Select policies to delete" "$${POLICY_ARRAY[@]}"); \
	if [ $${#SELECTED[@]} -eq 0 ]; then echo ""; echo "No policies selected."; echo; echo; exit 0; fi; \
	echo; \
	for policy in "$${SELECTED[@]}"; do \
		echo "Deleting policy: $${policy}"; \
		make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao bao policy delete $${policy}" 2>/dev/null; \
	done; \
	echo; echo

.PHONY: create-policy # Create a deploy repo policy (usage: make create-policy repo=d2-admin)
create-policy:
	@if [ -z "$${repo}" ]; then echo "ERROR: repo is required (e.g., make create-policy repo=d2-admin)" >&2; exit 1; fi; \
	echo "Creating policy: $${repo}-deploy (read sops/$${repo}/*, sign SSH keys)"; \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	POLICY=$$(printf 'path "secret/data/sops/%s/*" {\n  capabilities = ["read"]\n}\n\npath "ssh-client-signer/sign/woodpecker-short-lived" {\n  capabilities = ["create", "update"]\n}' "$${repo}" | base64 -w0); \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; echo $${POLICY} | base64 -d | bao policy write $${repo}-deploy -; echo; echo'"

.PHONY: create-approle # Create an AppRole for a deploy repo (usage: make create-approle repo=d2-admin)
create-approle:
	@if [ -z "$${repo}" ]; then echo "ERROR: repo is required (e.g., make create-approle repo=d2-admin)" >&2; exit 1; fi; \
	echo "Creating AppRole: $${repo}-deploy (policy: $${repo}-deploy, 20m TTL)"; \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	ROLE=$$(printf '{"token_policies":"%s-deploy","token_ttl":"20m","token_max_ttl":"30m","secret_id_ttl":"0"}' "$${repo}" | base64 -w0); \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; echo $${ROLE} | base64 -d | bao write auth/approle/role/$${repo}-deploy -; echo; echo'"

.PHONY: get-role-id # Get an AppRole role ID (usage: make get-role-id repo=d2-admin)
get-role-id:
	@if [ -z "$${repo}" ]; then echo "ERROR: repo is required (e.g., make get-role-id repo=d2-admin)" >&2; exit 1; fi; \
	TRAEFIK_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get OPENBAO_TRAEFIK_HOST); \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; echo \"## $${TRAEFIK_HOST} Role ID: $${repo}\"; bao read -field=role_id auth/approle/role/$${repo}-deploy/role-id; echo; echo'"

.PHONY: generate-secret-id # Generate an AppRole secret ID (usage: make generate-secret-id repo=d2-admin)
generate-secret-id:
	@if [ -z "$${repo}" ]; then echo "ERROR: repo is required (e.g., make generate-secret-id repo=d2-admin)" >&2; exit 1; fi; \
	TRAEFIK_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get OPENBAO_TRAEFIK_HOST); \
	echo "Enter the root token:"; \
	read -rs BAO_TOKEN; export BAO_TOKEN; \
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -e BAO_TOKEN -T openbao /bin/sh -c 'echo; echo \"## $${TRAEFIK_HOST} Secret Key: $${repo}\"; bao write -field=secret_id -f auth/approle/role/$${repo}-deploy/secret-id; echo; echo'"

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
