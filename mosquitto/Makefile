ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask MOSQUITTO_TRAEFIK_HOST "Enter the MQTT domain name" mqtt.${ROOT_DOMAIN}
