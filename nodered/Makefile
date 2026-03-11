ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} NODERED_TRAEFIK_HOST "Enter the nodered domain name" nodered${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} NODERED_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} NODERED_IP_SOURCERANGE "Enter the IP source range filter (0.0.0.0/0 to allow all)" "$${NODERED_IP_SOURCERANGE:-0.0.0.0/0}"
	@${BIN}/reconfigure_ask ${ENV_FILE} NODERED_WEBHOOK_TRAEFIK_HOST "Enter the webhook domain name (separate host, no mTLS)" nodered-webhooks${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} NODERED_WEBHOOK_IP_SOURCERANGE "Enter the webhook IP source range (use 0.0.0.0/32 to block all)" "$${NODERED_WEBHOOK_IP_SOURCERANGE:-0.0.0.0/32}"
	@${BIN}/reconfigure_auth ${ENV_FILE} NODERED


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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:nodered instance=@NODERED_INSTANCE traefik_host=@NODERED_TRAEFIK_HOST http_auth=NODERED_HTTP_AUTH http_auth_var=@NODERED_HTTP_AUTH ip_sourcerange=@NODERED_IP_SOURCERANGE webhook_traefik_host=@NODERED_WEBHOOK_TRAEFIK_HOST webhook_ip_sourcerange=@NODERED_WEBHOOK_IP_SOURCERANGE oauth2=NODERED_OAUTH2 authorized_group=NODERED_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=NODERED_MTLS_AUTH mtls_authorized_certs=NODERED_MTLS_AUTHORIZED_CERTS homepage_labels_enable=NODERED_HOMEPAGE_LABELS_ENABLE homepage_group_nodered=NODERED_HOMEPAGE_GROUP_NODERED homepage_name_nodered=NODERED_HOMEPAGE_NAME_NODERED homepage_icon_nodered=NODERED_HOMEPAGE_ICON_NODERED homepage_description_nodered=NODERED_HOMEPAGE_DESCRIPTION_NODERED homepage_show_stats_nodered=NODERED_HOMEPAGE_SHOW_STATS_NODERED

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=nodered

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo

.PHONY: request-bot-flow # Generate a Node-RED flow JSON for the request-bot
request-bot-flow:
	@export SUBJECT_PREFIX=$$(${BIN}/ask_echo "Enter the NATS subject prefix (e.g. hookshot.d2-admin)"); \
	export PREFIX_ID=$$(echo "$${SUBJECT_PREFIX}" | tr '.' '_' | tr '-' '_'); \
	export NATS_URL=$$(${BIN}/ask_echo "Enter the NATS server URL" "nats://nats.example.com:4222"); \
	export NATS_CA_FILE=$$(${BIN}/ask_echo "Enter the path to the NATS CA certificate" "/data/certs/root_ca.crt"); \
	export NATS_CERT_FILE=$$(${BIN}/ask_echo "Enter the path to the NATS client certificate" "/data/certs/client.crt"); \
	export NATS_KEY_FILE=$$(${BIN}/ask_echo "Enter the path to the NATS client key" "/data/certs/client.key"); \
	export MATRIX_SERVER=$$(${BIN}/ask_echo "Enter the Matrix homeserver name" "matrix.example.com"); \
	export MATRIX_ROOM_ID=$$(${BIN}/ask_echo "Enter the Matrix room ID (e.g. !abc123:example.com)"); \
	OUTPUT="request_bot_flow_$${SUBJECT_PREFIX//\./_}.json"; \
	envsubst '$$PREFIX_ID,$$SUBJECT_PREFIX,$$NATS_URL,$$NATS_CA_FILE,$$NATS_CERT_FILE,$$NATS_KEY_FILE,$$MATRIX_SERVER,$$MATRIX_ROOM_ID' \
		< templates/request_bot_flow.json > "$${OUTPUT}"; \
	echo; \
	echo "Generated: $${OUTPUT}"; \
	echo "Import this file into Node-RED via Menu > Import > select file."
