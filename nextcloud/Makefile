ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask NEXTCLOUD_TRAEFIK_HOST "Enter the nextcloud domain name" nc.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask OBJECTSTORE_S3_HOST "Enter the Primary S3 endpoint domain name"
	@${BIN}/reconfigure_ask OBJECTSTORE_S3_BUCKET "Enter the Primary S3 bucket name"
	@${BIN}/reconfigure_ask OBJECTSTORE_S3_KEY "Enter the Primary S3 Access Key"
	@${BIN}/reconfigure_ask OBJECTSTORE_S3_SECRET "Enter the Primary S3 Secret Key"
	@${BIN}/reconfigure DATABASE_PASSWORD=$(shell openssl rand -hex 45)
	@${BIN}/reconfigure_ask BACKUP_S3_HOST "Enter the Backup S3 endpoint domain name"
	@${BIN}/reconfigure_ask BACKUP_S3_BUCKET "Enter the Backup S3 bucket name"
	@${BIN}/reconfigure_ask BACKUP_S3_KEY "Enter the Backup S3 Access Key"
	@${BIN}/reconfigure_ask BACKUP_S3_SECRET "Enter the Backup S3 Secret Key"
	@${BIN}/reconfigure BACKUP_ENCRYPTION_PASSWORD=$(shell openssl rand -hex 45)

.PHONY: backup_postgres # Backup the database to S3 immediately
backup_postgres:
	@${BIN}/confirm yes "This will backup the database to S3 right now"
	docker-compose exec postgres_backup /bin/sh /backup.sh

.PHONY: backup_app # Backup the nextcloud configuration to S3 immediately
backup_app:
	@${BIN}/confirm yes "This will backup the nextcloud configuration to S3 right now"
	docker-compose exec app_backup /bin/sh /bin/backup

.PHONY: restore_postgres # Restore database from backup
restore_postgres:
	@${BIN}/confirm no "This will restore the database from backup"
	docker-compose exec postgres_backup /bin/sh /restore.sh
	@echo "Check the restore logs to monitor progress: docker-compose logs postgres_restore"

.PHONY: restore_app # Restore app config from backup
restore_app:
	@${BIN}/confirm no "This will restore the nextcloud configuration from backup"
	docker-compose exec app_backup /usr/bin/restic restore -t / latest
	@echo "Check the restore logs to monitor progress: docker-compose logs app_restore"

