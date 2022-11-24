ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} MINIO_TRAEFIK_HOST "Enter the minio domain name" s3.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} MINIO_CONSOLE_TRAEFIK_HOST "Enter the minio domain name" s3-console.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} MINIO_ROOT_USER "Enter the minio root username" root
	@${BIN}/reconfigure ${ENV_FILE} MINIO_ROOT_PASSWORD=$(shell openssl rand -hex 45)

.PHONY: bucket # Make a bucket and access credentials
bucket:
	ENV_FILE=${ENV_FILE} ./create_bucket_and_user.sh

.PHONY: mc # Run mc shell
mc:
	./mc_shell.sh

