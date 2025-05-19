ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-custom-build
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} NEXTCLOUD_TRAEFIK_HOST "Enter the nextcloud domain name" nextcloud${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} NEXTCLOUD_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} NEXTCLOUD

	@echo
	@echo "By default, Primary Storage is stored in the \`nextcloud_data\` docker volume. Optionally, you can store this data externally in an S3 Bucket instead."
	@${BIN}/reconfigure_choose ${ENV_FILE} NEXTCLOUD_PRIMARY_STORAGE "Choose where to store Primary Storage:" "Docker Volume" "S3 Bucket"
	@echo
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get NEXTCLOUD_PRIMARY_STORAGE) == "S3 Bucket" ]] && \
		${BIN}/reconfigure_ask ${ENV_FILE} NEXTCLOUD_OBJECTSTORE_S3_HOST "Enter the Primary S3 endpoint domain name" && \
		${BIN}/reconfigure_ask ${ENV_FILE} NEXTCLOUD_OBJECTSTORE_S3_BUCKET "Enter the Primary S3 bucket name" && \
		${BIN}/reconfigure_ask ${ENV_FILE} NEXTCLOUD_OBJECTSTORE_S3_KEY "Enter the Primary S3 Access Key" && \
		${BIN}/reconfigure_ask ${ENV_FILE} NEXTCLOUD_OBJECTSTORE_S3_SECRET "Enter the Primary S3 Secret Key" || true
	@echo
	@echo "Enter the connection info for the Backup"
	@${BIN}/reconfigure_password ${ENV_FILE} NEXTCLOUD_DATABASE_PASSWORD 45
	@${BIN}/reconfigure_ask ${ENV_FILE} NEXTCLOUD_BACKUP_S3_HOST "Enter the Backup S3 endpoint domain name"
	@${BIN}/reconfigure_ask ${ENV_FILE} NEXTCLOUD_BACKUP_S3_BUCKET "Enter the Backup S3 bucket name"
	@${BIN}/reconfigure_ask ${ENV_FILE} NEXTCLOUD_BACKUP_S3_KEY "Enter the Backup S3 Access Key"
	@${BIN}/reconfigure_ask ${ENV_FILE} NEXTCLOUD_BACKUP_S3_SECRET "Enter the Backup S3 Secret Key"
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} NEXTCLOUD_PHP_UPLOAD_LIMIT "Enter the maximum PHP file upload size (e.g., \"512M\" or \"2G\")"
	@${BIN}/reconfigure_ask ${ENV_FILE} NEXTCLOUD_PHP_MEMORY_LIMIT "Enter the PHP memory limit (should match or exceed the max file upload size)"
	@echo
	@echo "If you want to have Nextcloud access your already-existing files (e.g., your photo library), the \"External Storage Support\" app in Nextcloud allows you to mount external storage (FTP or SFTP servers, S3 or SWIFT object stores, other Nextcloud servers, WebDAV servers). If none of those protocols work for you, you can map a named Docker volume to a mountpoint in the Nextcloud container and then use the \"External Storage Support\" app to configure Nextcloud to use this mountpoint. Once you create a named Docker volume, you can either copy your files into the volume's path on the host (e.g., \`/var/lib/docker/volumes/nextcloud_<volume-name>/_data/\`), or you can replace that directory on the host with a symlink to another directory or mountpoint that already contains your files."
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} NEXTCLOUD_EXTRA_VOLUME_NAME "Enter an additional volume name (leave blank to not mount an additional volume)"

	@echo
	@${BIN}/reconfigure_password ${ENV_FILE} NEXTCLOUD_BACKUP_ENCRYPTION_PASSWORD 45

.PHONY: override-hook
override-hook:
#### This sets the override template variables for docker-compose.instance.yaml:
#### The template dynamically renders to docker-compose.override_{DOCKER_CONTEXT}_{INSTANCE}.yaml
#### These settings are used to automatically generate the service container labels, and traefik config, inside the template.
#### The variable arguments have three forms: `=` `=:` `=@`
####   name=VARIABLE_NAME    # sets the template 'name' field to the value of VARIABLE_NAME found in the .env file
####                         # (this hardcodes the value into docker-compose.override.yaml)
####   name=:VARIABLE_NAME   # sets the template 'name' field to the literal string 'VARIABLE_NAME'
####                         # (this hardcodes the string into docker-compose.override.yaml)
####   name=@VARIABLE_NAME   # sets the template 'name' field to the literal string '${VARIABLE_NAME}'
####                         # (used for regular docker-compose expansion of env vars by name.)
	@${BIN}/docker_compose_override ${ENV_FILE} project=:nextcloud instance=@NEXTCLOUD_INSTANCE traefik_host=@NEXTCLOUD_TRAEFIK_HOST http_auth=NEXTCLOUD_HTTP_AUTH http_auth_var=@NEXTCLOUD_HTTP_AUTH ip_sourcerange=@NEXTCLOUD_IP_SOURCERANGE oauth2=NEXTCLOUD_OAUTH2 authorized_group=NEXTCLOUD_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=NEXTCLOUD_MTLS_AUTH mtls_authorized_certs=NEXTCLOUD_MTLS_AUTHORIZED_CERTS primary_storage=NEXTCLOUD_PRIMARY_STORAGE additional_volume=NEXTCLOUD_EXTRA_VOLUME_NAME objectstore_s3_host=@NEXTCLOUD_OBJECTSTORE_S3_HOST objectstore_s3_bucket=@NEXTCLOUD_OBJECTSTORE_S3_BUCKET objectstore_s3_key=@NEXTCLOUD_OBJECTSTORE_S3_KEY objectstore_s3_secret=@NEXTCLOUD_OBJECTSTORE_S3_SECRET

.PHONY: build # Build the container images
build:
	docker build -t localhost/nextcloud-restic-backup $(shell ${BIN}/dotenv -f ${ENV_FILE} get NEXTCLOUD_BACKUP_APP_GIT_SRC)
	docker compose --env-file=${ENV_FILE} build
	@make -e --no-print-directory override instance=${INSTANCE}
	@[[ -z "${NO_HOOKS}" ]] && make --no-print-directory build-hook-pre-rule-exists 2>/dev/null && make --no-print-directory build-hook-pre || true
	@export COMPOSE_PROFILES="$${DOCKER_COMPOSE_PROFILES:-$$(${BIN}/dotenv -f "${ENV_FILE}" get DOCKER_COMPOSE_PROFILES)}"; make --no-print-directory docker-compose-build EXTRA_ARGS="${EXTRA_ARGS}"
	@[[ -z "${NO_HOOKS}" ]] && make --no-print-directory build-hook-post-rule-exists 2>/dev/null && make --no-print-directory build-hook-post || true

#.PHONY: included-build
#included-build:
#	ROOT_DIR=${ROOT_DIR} ENV_FILE=${ENV_FILE} $(MAKE) -f ${ROOT_DIR}/_scripts/Makefile.build build

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

.PHONY: shell
shell:
	@container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'postgres' 'postgres_backup' 'redis' 'app' 'data_backup' 'cron' --default 'app'") && make --no-print-directory docker-compose-shell SERVICE=$${container}
