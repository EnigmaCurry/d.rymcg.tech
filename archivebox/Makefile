ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} ARCHIVEBOX_TRAEFIK_HOST "Enter the archivebox domain name" archivebox.${ROOT_DOMAIN}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} ARCHIVEBOX_HTTP_AUTH

.PHONY: admin # Create admin account
admin:
	@docker compose --env-file=${ENV_FILE} exec archivebox su -c "archivebox manage createsuperuser" archivebox

.PHONY: reset-password # Reset the application password (not the HTTP password)
reset-password:
	@read -p "Enter the username of the account to reset: " USERNAME && docker compose --env-file=${ENV_FILE} exec archivebox su -c "archivebox manage changepassword $${USERNAME}" archivebox
