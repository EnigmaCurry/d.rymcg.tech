ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask NEXTCLOUD_TRAEFIK_HOST "Enter the nextcloud domain name" nc.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask OBJECTSTORE_S3_HOST "Enter the S3 endpoint hostname"
	@${BIN}/reconfigure_ask OBJECTSTORE_S3_BUCKET "Enter the S3 bucket name for storage"
	@${BIN}/reconfigure_ask OBJECTSTORE_S3_REGION "Enter the S3 region"
	@${BIN}/reconfigure_ask OBJECTSTORE_S3_KEY "Enter the S3 Access Key"
	@${BIN}/reconfigure_ask OBJECTSTORE_S3_SECRET "Enter the S3 Secret Key"
	@${BIN}/reconfigure MYSQL_PASSWORD=$(shell openssl rand -base64 45)
