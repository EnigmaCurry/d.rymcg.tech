ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_TRAEFIK_HOST "Enter the postgres domain name" postgres.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_DB "Enter the database name"
	@${BIN}/reconfigure ${ENV_FILE} POSTGRES_USER=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB)
	@${BIN}/reconfigure_ask ${ENV_FILE} ALLOWED_IP_SOURCERANGE "Enter the allowed client IP address range (CIDR with netmask) (use 0.0.0.0/0 to allow all)" 0.0.0.0/0
	@${BIN}/reconfigure ${ENV_FILE} POSTGRES_PASSWORD=$(shell openssl rand -hex 45)

.PHONY: psql # Open psql shell
psql:
	@docker-compose --env-file ${ENV_FILE} exec --user postgres postgres /usr/bin/psql

.PHONY: client # Get client certificate and private key files
client:
	@docker-compose --env-file ${ENV_FILE} exec --user postgres postgres cat /etc/postgresql/root_ca.crt > $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_ca.crt && echo "Wrote ./$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_ca.crt"
	@docker-compose --env-file ${ENV_FILE} exec --user postgres postgres cat /etc/postgresql/client.crt > $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).crt && echo "Wrote ./$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).crt"
	@docker-compose --env-file ${ENV_FILE} exec --user postgres postgres cat /etc/postgresql/client.key > $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).key && echo "Wrote ./$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).key"
	@chmod 0600 *.crt *.key
	@echo
	@echo "To use psql run:"
	@echo "psql \"host=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST) port=$$(${BIN}/dotenv -f ${ENV_FILE} get EXTERNAL_TCP_PORT) user=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_USER) dbname=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB) sslmode=verify-full sslcert=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).crt sslkey=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).key sslrootcert=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_ca.crt\""
	@echo
	@echo ^^ Enjoy
	@echo
	@echo "Note: the certificate is database specific. You can only access this one."

.PHONY: clean
clean:
	rm -f *.crt *.key
