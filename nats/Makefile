ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

STEP=step-cli

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} NATS_DOCKER_CONTEXT=${DOCKER_CONTEXT}
	@${BIN}/reconfigure_ask ${ENV_FILE} NATS_TRAEFIK_HOST "Enter the NATS domain name" nats${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} NATS_INSTANCE=$${instance:-default}
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
