ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} SOCKET_TRAEFIK_HOST "Enter the websocketd domain name" socket.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} DEV_CONSOLE "Turn on dev console? true/false" false

