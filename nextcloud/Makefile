ROOT_DIR = ..
include ../_scripts/Makefile.projects-custom-build

.PHONY: config-hook # Configure .env file
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} NEXTCLOUD_TRAEFIK_HOST "Enter the nextcloud domain name" nc.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} OBJECTSTORE_S3_HOST "Enter the Primary S3 endpoint domain name"
	@${BIN}/reconfigure_ask ${ENV_FILE} OBJECTSTORE_S3_BUCKET "Enter the Primary S3 bucket name"
	@${BIN}/reconfigure_ask ${ENV_FILE} OBJECTSTORE_S3_KEY "Enter the Primary S3 Access Key"
	@${BIN}/reconfigure_ask ${ENV_FILE} OBJECTSTORE_S3_SECRET "Enter the Primary S3 Secret Key"
	@${BIN}/reconfigure ${ENV_FILE} DATABASE_PASSWORD=$(shell openssl rand -hex 45)
	@${BIN}/reconfigure_ask ${ENV_FILE} BACKUP_S3_HOST "Enter the Backup S3 endpoint domain name"
	@${BIN}/reconfigure_ask ${ENV_FILE} BACKUP_S3_BUCKET "Enter the Backup S3 bucket name"
	@${BIN}/reconfigure_ask ${ENV_FILE} BACKUP_S3_KEY "Enter the Backup S3 Access Key"
	@${BIN}/reconfigure_ask ${ENV_FILE} BACKUP_S3_SECRET "Enter the Backup S3 Secret Key"
	@${BIN}/reconfigure ${ENV_FILE} BACKUP_ENCRYPTION_PASSWORD=$(shell openssl rand -hex 45)

.PHONY: build # Build the container images
build:
	docker build -t localhost/nextcloud-restic-backup $(shell ${BIN}/dotenv -f ${ENV_FILE} get BACKUP_APP_GIT_SRC)
	docker compose --env-file=${ENV_FILE} build

.PHONY: backup_db # Backup the database to S3 immediately
backup_db:
	@${BIN}/confirm yes "This will backup the database to S3 right now"
	docker compose exec postgres_backup /bin/sh /backup.sh

.PHONY: backup_data # Backup the nextcloud data to S3 immediately
backup_data:
	@${BIN}/confirm yes "This will backup the nextcloud data to S3 right now"
	docker compose exec data_backup /bin/sh /bin/backup

.PHONY: backup # Backup data and database
backup: backup_data backup_db

.PHONY: restore_db # Restore database from backup
restore_db:
	@${BIN}/confirm no "This will restore the database from backup"
	docker compose exec postgres_backup /bin/sh /restore.sh

.PHONY: restore_data # Restore /var/www/html from backup
restore_data:
	@${BIN}/confirm no "This will restore the nextcloud data from backup"
	docker compose exec data_backup /usr/bin/restic restore -t / latest

.PHONY: enable_maintenance # Enable maintenance mode
enable_maintenance:
	docker compose exec data_backup /hooks/maintenance.sh on

.PHONY: disable_maintenance # Disable maintenance mode
disable_maintenance:
	docker compose exec data_backup /hooks/maintenance.sh off

