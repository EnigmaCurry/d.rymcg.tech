ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

STEP=step-cli

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} NATS_DOCKER_CONTEXT=${DOCKER_CONTEXT}
	@${BIN}/reconfigure_ask ${ENV_FILE} NATS_TRAEFIK_HOST "Enter the NATS domain name" nats${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} NATS_INSTANCE=$${instance:-default}
	@echo
	@echo "## The NATS client TCP port (4222) is always protected by mTLS."
	@echo "## This next question is about the HTTP monitoring web UI only."
	@echo
	@${BIN}/reconfigure_auth ${ENV_FILE} NATS
	@${BIN}/reconfigure_ask ${ENV_FILE} NATS_CLUSTER_NAME "Enter the NATS cluster name" nats
	@${BIN}/reconfigure_ask ${ENV_FILE} NATS_CLIENT_PORT "Enter the NATS client port to expose" 4222
	@${BIN}/reconfigure_ask ${ENV_FILE} NATS_STEP_CA_URL "Enter the Step-CA URL" $$(cat $$(${STEP} path)/config/defaults.json | jq -r '."ca-url"')
	@echo
	@echo "Retrieving Step-CA fingerprint from $$(${BIN}/dotenv -f ${ENV_FILE} get NATS_STEP_CA_URL)/roots.pem ..."
	@${BIN}/reconfigure_ask ${ENV_FILE} NATS_STEP_CA_FINGERPRINT "VERIFY the Step-CA fingerprint" $$(${STEP} ca root | ${STEP} certificate fingerprint)
	@${BIN}/reconfigure ${ENV_FILE} NATS_STEP_CA_TOKEN="" &>/dev/null
	@echo "Retrieving one-time-use token from Step-CA server."
	@echo "Get ready to enter your root Step-CA credentials!"
	@echo
	@${BIN}/reconfigure ${ENV_FILE} NATS_STEP_CA_TOKEN="$$(step-cli ca token $$(${BIN}/dotenv -f ${ENV_FILE} get NATS_TRAEFIK_HOST) --provisioner admin)"

.PHONY: override-hook
override-hook:
	@${BIN}/docker_compose_override ${ENV_FILE} project=:nats instance=@NATS_INSTANCE traefik_host=@NATS_TRAEFIK_HOST http_auth=NATS_HTTP_AUTH http_auth_var=@NATS_HTTP_AUTH ip_sourcerange=@NATS_IP_SOURCERANGE oauth2=NATS_OAUTH2 authorized_group=NATS_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=NATS_MTLS_AUTH mtls_authorized_certs=NATS_MTLS_AUTHORIZED_CERTS homepage_labels_enable=NATS_HOMEPAGE_LABELS_ENABLE homepage_group_nats=NATS_HOMEPAGE_GROUP_NATS homepage_name_nats=NATS_HOMEPAGE_NAME_NATS homepage_icon_nats=NATS_HOMEPAGE_ICON_NATS homepage_description_nats=NATS_HOMEPAGE_DESCRIPTION_NATS homepage_show_stats_nats=NATS_HOMEPAGE_SHOW_STATS_NATS

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=nats

.PHONY: cert # Create a client TLS certificate
cert:
	@${STEP} ca roots > certs/root_ca.crt
	@CN=$$(${BIN}/ask_echo "Enter the client domain (CN) to be certified" ${HOSTNAME}.clients.$$(${BIN}/dotenv -f ${ENV_FILE} get NATS_TRAEFIK_HOST)); ${STEP} ca certificate "$${CN}" "certs/$${CN}.crt" "certs/$${CN}.key" --provisioner admin --not-after "$$(${BIN}/dotenv -f ${ENV_FILE} get NATS_CLIENT_CERT_EXPIRATION_HOURS)"h

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
