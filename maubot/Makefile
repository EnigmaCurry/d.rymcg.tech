ROOT_DIR = ..
include ../_scripts/Makefile.projects-no-open

.PHONY: config-hook # Configure .env file
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} MAUBOT_TRAEFIK_HOST "Enter the maubot domain name" maubot.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} MATRIX_HOMESERVER "Enter the matrix homeserver"
	@${BIN}/reconfigure_ask ${ENV_FILE} MAUBOT_ADMIN_USER "Enter the maubot admin username to create" admin
	@${BIN}/reconfigure ${ENV_FILE} MAUBOT_ADMIN_PASSWORD=$(shell openssl rand -base64 45)

.PHONY: open # Open the web-browser to the service URL
open:
	${BIN}/open /_matrix/maubot

.PHONY: login
login:
	@echo "Login with the maubot client:"
	@echo "Use the same Admin username/password set in your .env file."
	@echo "Use the Server http://localhost:29316"
	@echo "Set the Alias as localhost"
	@echo ""
	@docker-compose --env-file ${ENV_FILE} exec maubot mbc login
	@echo ""
	@echo "Now login to the matrix account for maubots use:"
	@echo "Enter the Matrix homeserver domain, example: matrix.example.com"
	@echo "Enter the Matrix username by itself, example: maubot"
	@echo "Enter the Matrix password account."
	@docker-compose --env-file ${ENV_FILE} exec maubot mbc auth --update-client

