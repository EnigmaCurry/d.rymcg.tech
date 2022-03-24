ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} ARCHIVEBOX_TRAEFIK_HOST "Enter the archivebox domain name" archivebox.${ROOT_DOMAIN}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} ARCHIVEBOX_HTTP_AUTH
	@${BIN}/reconfigure ${ENV_FILE} SECRET_KEY=$$(openssl rand -hex 45)
	@${BIN}/reconfigure ${ENV_FILE} ARCHIVEBOX_USERNAME=admin
	@${BIN}/reconfigure ${ENV_FILE} ARCHIVEBOX_EMAIL=admin@localhost
	@${BIN}/reconfigure ${ENV_FILE} ARCHIVEBOX_PASSWORD=$$(openssl rand -hex 30)

.PHONY: admin # Create admin account
admin:
	@docker compose --env-file=${ENV_FILE} exec archivebox su -c "DJANGO_SUPERUSER_PASSWORD=$$(${BIN}/dotenv -f ${ENV_FILE} get ARCHIVEBOX_PASSWORD) archivebox manage createsuperuser --noinput --username $$(${BIN}/dotenv -f ${ENV_FILE} get ARCHIVEBOX_USERNAME) --email $$(${BIN}/dotenv -f ${ENV_FILE} get ARCHIVEBOX_EMAIL)" archivebox

.PHONY: api-dev
api-dev:
	make build
	@docker-compose --env-file=${ENV_FILE} stop public-api-gateway
	@docker-compose --env-file=${ENV_FILE} run --rm public-api-gateway
