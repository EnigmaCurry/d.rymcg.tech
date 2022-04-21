ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_TRAEFIK_HOST "Enter the postgres domain name" postgres.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_DB "Enter the database name" tweedle
	@${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_LIMITED_USER "Enter the database user" $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB)
	@${BIN}/reconfigure_ask ${ENV_FILE} ALLOWED_IP_SOURCERANGE "Enter the allowed client IP address range (CIDR with netmask) (use 0.0.0.0/0 to allow all)"
	@${BIN}/reconfigure ${ENV_FILE} POSTGRES_ADMIN_PASSWORD=$(shell openssl rand -hex 45)

.PHONY: psql # Open psql shell
psql:
	@docker-compose --env-file ${ENV_FILE} exec --user postgres postgres /usr/bin/psql

.PHONY: shell # Open bash shell
shell:
	@docker-compose --env-file ${ENV_FILE} exec --user postgres postgres /bin/bash

.PHONY: client # Get client certificate and private key files
client:
	@docker-compose --env-file ${ENV_FILE} exec --user postgres postgres cat /etc/postgresql/root_ca.crt > $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_ca.crt && echo "Wrote ./$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_ca.crt"
	@docker-compose --env-file ${ENV_FILE} exec --user postgres postgres cat /etc/postgresql/client.crt > $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_LIMITED_USER).crt && echo "Wrote ./$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_LIMITED_USER).crt"
	@docker-compose --env-file ${ENV_FILE} exec --user postgres postgres cat /etc/postgresql/client.key > $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_LIMITED_USER).key && echo "Wrote ./$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_LIMITED_USER).key"
	@docker-compose --env-file ${ENV_FILE} exec --user postgres postgres cat /etc/postgresql/client.pk8.key > $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_LIMITED_USER).pk8.key && echo "Wrote ./$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_LIMITED_USER).pk8.key"
	@chmod 0600 *.crt *.key
	@echo
	@echo "To use psql, put this alias in your ~/.bashrc :"
	@echo
	@echo "alias psql=\"psql '$$(make --no-print-directory connection-string)'\""
	@echo
	@echo ^^ Enjoy

.PHONY: clean
clean:
	rm -f *.crt *.key

.PHONY: diagram # Make a pictoral diagram of your database table models
diagram:
	@echo TODO

.PHONY: certificates # Make new certificates (overwriting the old ones)
certificates: build
	@${BIN}/confirm no "This will destroy the existing CA, server, and client certificates and create new ones."
	@docker-compose --env-file=${ENV_FILE} run -e FORCE_NEW_CERTIFICATES=true config
	@docker-compose --env-file=${ENV_FILE} restart postgres

.PHONY: connection-string # Get the connection string
connection-string:
	@echo "postgresql://$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_LIMITED_USER)@$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST):$$(${BIN}/dotenv -f ${ENV_FILE} get EXTERNAL_TCP_PORT)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB)?sslmode=verify-full&sslcert=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_LIMITED_USER).crt&sslkey=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_LIMITED_USER).key&sslrootcert=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_ca.crt"

.PHONY: import-chinook # Import Chinook sample database
import-chinook:
	docker-compose --env-file=${ENV_FILE} exec postgres /bin/sh -c 'createdb chinook && psql -c "create role chinook; grant chinook to $${POSTGRES_LIMITED_USER};" && PGUSER=$${POSTGRES_LIMITED_USER} pgloader https://github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite_AutoIncrementPKs.sqlite pgsql:///chinook'

.PHONY: psql-alias # Get the psql alias with baked connection string
psql-alias:
	@echo "alias psql=\"psql '$$(make --no-print-directory connection-string)'\""
