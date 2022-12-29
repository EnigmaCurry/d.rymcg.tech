ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} MOSQUITTO_TRAEFIK_HOST "Enter the MQTT domain name" mqtt.${ROOT_DOMAIN}

.PHONY: admin # Create admin account (this clears ALL accounts and creates a new admin)
admin:
	./create_user.sh admin

.PHONY: user # Create an additional account
user:
	./create_user.sh

.PHONY: list-users # List the user accounts and hashed passwords
list-users:
	docker compose exec mosquitto cat /mosquitto/config/passwd


