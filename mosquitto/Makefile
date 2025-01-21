ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

STEP=step-cli

.PHONY: config-hook
config-hook:
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

.PHONY: admin # Create admin account (this clears ALL accounts and creates a new admin)
admin:
	@ENV_FILE=${ENV_FILE} ./create_user.sh admin

.PHONY: user # Create an additional account
user:
	@ENV_FILE=${ENV_FILE} ./create_user.sh

.PHONY: list-users # List the user accounts and hashed passwords
list-users:
	docker compose --env-file=${ENV_FILE} exec mosquitto cat /mosquitto/config/passwd

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=mosquitto

.PHONY: client # Create a temporary client shell
client:
	@docker run --rm -it eclipse-mosquitto:$$(${BIN}/dotenv -f ${ENV_FILE} get MOSQUITTO_VERSION) /bin/sh

