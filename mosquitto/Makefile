ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} MOSQUITTO_TRAEFIK_HOST "Enter the MQTT domain name" mqtt.${ROOT_DOMAIN}

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

