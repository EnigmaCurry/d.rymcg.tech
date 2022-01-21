ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask MINIO_TRAEFIK_HOST "Enter the minio domain name" s3.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask MINIO_CONSOLE_TRAEFIK_HOST "Enter the minio domain name" console.s3.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask MINIO_ROOT_USER "Enter the minio root username" root
	@${BIN}/reconfigure MINIO_ROOT_PASSWORD=$(shell openssl rand -hex 45)



