ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} POSTGRES_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_HOST "Enter the postgres domain name" postgres${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_EXTERNAL_TCP_PORT "Enter the unique public TCP port to listen on" 5432
	@${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_DB "Enter the main database name for this instance" tweedle
	@${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_ALLOWED_IP_SOURCERANGE "Enter the allowed client IP address range (CIDR with netmask) (use 0.0.0.0/0 to allow all)"
	@${BIN}/reconfigure_password ${ENV_FILE} POSTGRES_ADMIN_PASSWORD
	@echo
	@${BIN}/reconfigure ${ENV_FILE} POSTGRES_PGBACKREST=$$(${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_PGBACKREST)" == "true" && echo yes || echo no) "Do you want to enable backups" "?" && echo true || echo false)
	@if [[ "$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_PGBACKREST)" == "true" ]]; then ${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_PGBACKREST_ENCRYPTION_PASSPHRASE)" != "" && echo yes || echo no) "Do you want to enable encryption for the backups" "?" && ${BIN}/reconfigure_password ${ENV_FILE} POSTGRES_PGBACKREST_ENCRYPTION_PASSPHRASE && echo && echo "Remember to backup a copy of your .env file! It contains your encryption key!" || ${BIN}/reconfigure ${ENV_FILE} POSTGRES_PGBACKREST_ENCRYPTION_PASSPHRASE=; fi

	@echo
	@if [[ "$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_PGBACKREST)" == "true" ]]; then CHOICE="$$(${BIN}/script-wizard choose 'Choose the backup repositories to enable:' 'Local volume only' 'Local volume + Remote S3' 'Remote S3 only')"; case "$${CHOICE}" in 'Local volume only') ${BIN}/reconfigure ${ENV_FILE} POSTGRES_PGBACKREST_LOCAL=true; ${BIN}/reconfigure ${ENV_FILE} POSTGRES_PGBACKREST_S3=false ;; 'Local volume + Remote S3') ${BIN}/reconfigure ${ENV_FILE} POSTGRES_PGBACKREST_LOCAL=true; ${BIN}/reconfigure ${ENV_FILE} POSTGRES_PGBACKREST_S3=true;; 'Remote S3 only') ${BIN}/reconfigure ${ENV_FILE} POSTGRES_PGBACKREST_LOCAL=false; ${BIN}/reconfigure ${ENV_FILE} POSTGRES_PGBACKREST_S3=true;; esac; fi

	@echo
	@if [[ "$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_PGBACKREST)" == "true" ]] && [[ "$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_PGBACKREST_LOCAL)" == "true" ]]; then ${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_PGBACKREST_LOCAL_RETENTION_FULL "Enter the number of full backups to retain locally" && ${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_PGBACKREST_LOCAL_RETENTION_DIFF "Enter the number of differential backups to retain locally"; fi

	@echo
	@if [[ "$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_PGBACKREST)" == "true" ]] && [[ "$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_PGBACKREST_S3)" == "true" ]]; then ${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_PGBACKREST_S3_ENDPOINT "Enter the S3 endpoint (domain:port) (may omit :port if its 443)" && ${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_PGBACKREST_S3_REGION "Enter the S3 region" && ${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_PGBACKREST_S3_BUCKET "Enter the S3 bucket name" && ${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_PGBACKREST_S3_KEY_ID "Enter the S3 access key ID" && ${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_PGBACKREST_S3_KEY_SECRET "Enter the S3 secret key" && ${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_PGBACKREST_S3_RETENTION_FULL "Enter the number of full backups to retain on S3" && ${BIN}/reconfigure_ask ${ENV_FILE} POSTGRES_PGBACKREST_S3_RETENTION_DIFF "Enter the number of differential backups to retain on S3"; fi


.PHONY: psql # Open psql shell
psql:
	@make --no-print-directory docker-compose-shell SERVICE=postgres USERNAME=$${USERNAME:-postgres} CD=/var/lib/postgresql COMMAND=/usr/bin/psql

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=postgres USERNAME=$${USERNAME:-root} CD=/var/lib/postgresql

.PHONY: client # Get client certificate and private key files
client:
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec --user postgres postgres cat /etc/postgresql/root_ca.crt" > $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_ca.crt && echo "Wrote ./$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_ca.crt"
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec --user postgres postgres cat /etc/postgresql/client.crt" > $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).crt && echo "Wrote ./$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).crt"
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec --user postgres postgres cat /etc/postgresql/client.key" > $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).key && echo "Wrote ./$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).key"
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec --user postgres postgres cat /etc/postgresql/client.pk8.key" > $$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).pk8.key && echo "Wrote ./$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).pk8.key"
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
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="run -e FORCE_NEW_CERTIFICATES=true config"
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="restart postgres"

.PHONY: connection-string
connection-string:
	@echo "postgresql://$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB)@$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST):$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_EXTERNAL_TCP_PORT)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB)?sslmode=verify-full&sslcert=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).crt&sslkey=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).key&sslrootcert=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_ca.crt"

.PHONY: connection-variables
connection-variables:
	@echo "## PostgreSQL connection  variables -"
	@echo "## Put these in your ~/.bashrc to configure psql and most other clients ::"
	@echo export PGHOST=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)
	@echo export PGPORT=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_EXTERNAL_TCP_PORT)
	@echo export PGUSER=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB)
	@echo export PGDATABASE=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB)
	@echo export PGSSLMODE=verify-full
	@echo export PGSSLCERT=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).crt
	@echo export PGSSLKEY=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).key
	@echo export PGSSLROOTCERT=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_ca.crt

.PHONY: localdb
localdb: client
	@export PGHOST=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST); export PGPORT=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_EXTERNAL_TCP_PORT); export PGUSER=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB); export PGDATABASE=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB); export PGSSLMODE=verify-full; export PGSSLCERT=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).crt; export PGSSLKEY=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB).key; export PGSSLROOTCERT=$$(realpath .)/$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)_ca.crt; export DATABASE_URL="postgres://$${PGHOST}/$${PGDATABASE}"; bash --rcfile <(echo -e "PS1='\[\033[01;31m\]DB:[\[\033[01;37m\]$${PGUSER}@$${PGHOST}:${INSTANCE}\[\033[01;31m\]] \[\033[01;32m\][\u@\h\[\033[01;37m\] \W\[\033[01;32m\]]\[\033[0m\] $$ ';") -i

.PHONY: chinook # Import Chinook sample database
chinook:
	@POSTGRES_DB=$$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_DB); COMMAND="createdb chinook && psql -c 'create role chinook; grant chinook to $${POSTGRES_DB}; alter database chinook OWNER TO $${POSTGRES_DB};' && PGUSER=$${POSTGRES_DB} pgloader https://github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite_AutoIncrementPKs.sqlite pgsql:///chinook"; make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec postgres /bin/sh -c $${COMMAND@Q}"

.PHONY: psql-alias # Get the psql alias with baked connection string
psql-alias:
	@echo "alias psql=\"psql '$$(make --no-print-directory connection-string)'\""

.PHONY: backup # Enable backups
backup:
	@ENV_FILE="${ENV_FILE}" PROJECT_NAME="${PROJECT_NAME}" INSTANCE_SUFFIX="${INSTANCE_SUFFIX}" ./backup.sh
