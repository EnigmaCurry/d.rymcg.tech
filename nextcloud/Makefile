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
