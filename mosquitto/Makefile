ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

STEP=step-cli

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} MOSQUITTO_DOCKER_CONTEXT=${DOCKER_CONTEXT}
	@${BIN}/reconfigure_ask ${ENV_FILE} MOSQUITTO_TRAEFIK_HOST "Enter the MQTT domain name" mqtt.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} MOSQUITTO_STEP_CA_URL "Enter the Step-CA URL" $$(cat $$(${STEP} path)/config/defaults.json | jq -r '."ca-url"')
	@echo
	@echo "Retrieving Step-CA fingerprint from $$(${BIN}/dotenv -f ${ENV_FILE} get MOSQUITTO_STEP_CA_URL)/roots.pem ..."
	@${BIN}/reconfigure_ask ${ENV_FILE} MOSQUITTO_STEP_CA_FINGERPRINT "VERIFY the Step-CA fingerprint" $$(${STEP} ca root | ${STEP} certificate fingerprint)
	@${BIN}/reconfigure ${ENV_FILE} MOSQUITTO_STEP_CA_TOKEN="" &>/dev/null # clear one-time-user token each time
	@echo "Retrieving one-time-use token from Step-CA server."
	@echo "Get ready to enter your root Step-CA ceredentials!"
	@echo
	@${BIN}/reconfigure ${ENV_FILE} MOSQUITTO_STEP_CA_TOKEN="$$(step-cli ca token mqtt.z.rymcg.tech --provisioner admin)"

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=mosquitto

.PHONY: cert # Create a client TLS certificate
cert:
	@${STEP} ca roots > certs/root_ca.crt
	@CN=$$(${BIN}/ask_echo "Enter the client domain (CN) to be certified" ${HOSTNAME}.clients.$$(${BIN}/dotenv -f ${ENV_FILE} get MOSQUITTO_TRAEFIK_HOST)); ${STEP} ca certificate "$${CN}" "certs/$${CN}.crt" "certs/$${CN}.key" --provisioner admin --not-after "$$(${BIN}/dotenv -f ${ENV_FILE} get MOSQUITTO_CLIENT_CERT_EXPIRATION_HOURS)"h

