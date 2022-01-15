ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask MAUBOT_TRAEFIK_HOST "Enter the maubot domain name" maubot.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask MATRIX_HOMESERVER "Enter the matrix homeserver"
	@${BIN}/reconfigure_ask MAUBOT_ADMIN_USER "Enter the maubot admin username to create" admin
	@${BIN}/reconfigure MAUBOT_ADMIN_PASSWORD=$(shell openssl rand -base64 45)



