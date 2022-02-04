ROOT_DIR = ..
include ../_scripts/Makefile.projects-custom-build

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

.PHONY: build # Build the container images
build:
	docker build -t localhost/lobaro-restic-backup-docker $(shell ${BIN}/dotenv get BACKUP_APP_GIT_SRC)
	docker-compose build

.PHONY: backup # Backup /var/www/html and the database to S3 immediately
backup:
	@${BIN}/confirm yes "This will backup the nextcloud data and database to S3 right now"
	docker-compose exec backup /bin/sh /bin/backup

.PHONY: restore # Restore /var/www/html and the database from backup
restore_data:
	@${BIN}/confirm no "This will restore the nextcloud data from backup"
	docker-compose exec backup /usr/bin/restic restore -t / latest

.PHONY: enable_maintenance # Enable maintenance mode
enable_maintenance:
	docker-compose exec backup /hooks/maintenance.sh on

.PHONY: disable_maintenance # Disable maintenance mode
disable_maintenance:
	docker-compose exec backup /hooks/maintenance.sh off

# .PHONY: backup_db # Backup the database to S3 immediately
# backup_db:
# 	@${BIN}/confirm yes "This will backup the database to S3 right now"
# 	docker-compose exec postgres_backup /bin/sh /backup.sh

# .PHONY: restore_db # Restore database from backup
# restore_db:
# 	@${BIN}/confirm no "This will restore the database from backup"
# 	docker-compose exec postgres_backup /bin/sh /restore.sh
