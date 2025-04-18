ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_TRAEFIK_HOST "Enter the postgres domain name" postgres.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_DB "Enter the database name" tweedle
	@${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_ALLOWED_IP_SOURCERANGE "Enter the allowed client IP address range (CIDR with netmask) (use 0.0.0.0/0 to allow all)"
	@${BIN}/reconfigure ${ENV_FILE} POSTGRES_ADMIN_PASSWORD=$(shell openssl rand -hex 45)

.PHONY: psql # Open psql shell
psql:
	@docker compose --env-file ${ENV_FILE} exec --user postgres postgres /usr/bin/psql

.PHONY: shell
shell:
	@make --no-print-directory docker compose-shell SERVICE=postgres

.PHONY: client # Get client certificate and private key files
client:
	@docker compose --env-file ${ENV_FILE} exec --user postgres postgres cat /etc/postgresql/root_ca.crt > $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_ca.crt && echo "Wrote ./$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_ca.crt"
	@docker compose --env-file ${ENV_FILE} exec --user postgres postgres cat /etc/postgresql/client.crt > $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).crt && echo "Wrote ./$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).crt"
	@docker compose --env-file ${ENV_FILE} exec --user postgres postgres cat /etc/postgresql/client.key > $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).key && echo "Wrote ./$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).key"
	@docker compose --env-file ${ENV_FILE} exec --user postgres postgres cat /etc/postgresql/client.pk8.key > $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).pk8.key && echo "Wrote ./$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).pk8.key"
	@chmod 0600 *.crt *.key
	@echo
	@make --no-print-directory connection-variables
	@echo
	@echo ^^ Enjoy

.PHONY: clean-hook # Remove client certificates and keys from local directory
clean-hook:
	rm -f *.crt *.key
	@echo "# Removed postgresql client certificates."

.PHONY: diagram # Make a pictoral diagram of your database table models
diagram:
	@echo TODO

.PHONY: certificates # Make new certificates (overwriting the old ones)
certificates: build
	@${BIN}/confirm no "This will destroy the existing CA, server, and client certificates and create new ones."
	@docker compose --env-file=${ENV_FILE} run -e FORCE_NEW_CERTIFICATES=true config
	@docker compose --env-file=${ENV_FILE} restart postgres

.PHONY: connection-string
connection-string:
	@echo "postgresql://$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB)@$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST):$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_EXTERNAL_TCP_PORT)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB)?sslmode=verify-full&sslcert=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).crt&sslkey=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).key&sslrootcert=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_ca.crt"

.PHONY: connection-variables
connection-variables:
	@echo "## PostgreSQL connection  variables -"
	@echo "## Put these in your ~/.bashrc to configure psql and most other clients ::"
	@echo export PGHOST=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)
	@echo export PGPORT=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_EXTERNAL_TCP_PORT)
	@echo export PGUSER=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB)
	@echo export PGDATABASE=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB)
	@echo export PGSSLMODE=verify-full
	@echo export PGSSLCERT=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).crt
	@echo export PGSSLKEY=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).key
	@echo export PGSSLROOTCERT=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_ca.crt

.PHONY: localdb
localdb: client
	@export PGHOST=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST); export PGPORT=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_EXTERNAL_TCP_PORT); export PGUSER=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB); export PGDATABASE=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB); export PGSSLMODE=verify-full; export PGSSLCERT=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).crt; export PGSSLKEY=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).key; export PGSSLROOTCERT=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_TRAEFIK_HOST)_ca.crt; export DATABASE_URL="postgres://$${PGHOST}/$${PGDATABASE}"; bash --rcfile <(echo -e "PS1='\[\033[01;31m\]DB:[\[\033[01;37m\]$${PGUSER}@$${PGHOST}:${INSTANCE}\[\033[01;31m\]] \[\033[01;32m\][\u@\h\[\033[01;37m\] \W\[\033[01;32m\]]\[\033[0m\] $$ ';") -i

.PHONY: chinook # Import Chinook sample database
chinook:
	@POSTGRES_DB=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB); set -x; docker compose --env-file=${ENV_FILE} exec postgres /bin/sh -c 'createdb chinook && PGUSER=root pgloader https://github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite_AutoIncrementPKs.sqlite pgsql:///chinook && psql -c "create role chinook;" && psql -d chinook -c "GRANT chinook to $${POSTGRES_DB}; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO chinook; GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO chinook;"'

.PHONY: drop-chinook # Delete the chinook sample database
drop-chinook:
	docker compose --env-file=${ENV_FILE} exec postgres /bin/sh -c 'psql -X -c "drop database chinook"' || true
	docker compose --env-file=${ENV_FILE} exec postgres /bin/sh -c 'psql -X -c "drop role chinook"' || true

.PHONY: psql-alias # Get the psql alias with baked connection string
psql-alias:
	@echo "alias psql=\"psql '$$(make --no-print-directory connection-string)'\""
