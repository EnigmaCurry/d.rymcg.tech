#!/bin/bash

configure_backups() {
    IFS=',' read -ra BACKUP_VOLUMES <<< "$(${BIN}/dotenv -f ${ENV_FILE} get BACKUP_VOLUMES)"    
    BACKUP_VOLUMES=$(array_to_json "${BACKUP_VOLUMES[@]}")
    readarray -t SELECTED_BACKUPS < <(wizard select --default "$BACKUP_VOLUMES" "Select all the volumes to backup" $(docker volume ls -q | grep "_"))
    ${BIN}/reconfigure ${ENV_FILE} BACKUP_VOLUMES="$(array_join "," "${SELECTED_BACKUPS[@]}")"
}

configure_cron() {
   	echo
	echo "# A cron expression represents a set of times, using 5 or 6 space-separated fields."
	echo "#"
	echo "# Field name   | Mandatory? | Allowed values  | Allowed special characters"
	echo "# ----------   | ---------- | --------------  | --------------------------"
	echo "# Seconds      | No         | 0-59            | * / , -"
	echo "# Minutes      | Yes        | 0-59            | * / , -"
	echo "# Hours        | Yes        | 0-23            | * / , -"
	echo "# Day of month | Yes        | 1-31            | * / , - ?"
	echo "# Month        | Yes        | 1-12 or JAN-DEC | * / , -"
	echo "# Day of week  | Yes        | 0-6 or SUN-SAT  | * / , - ?"
	echo "#"
	echo "# Month and Day-of-week field values are case insensitive."
	echo "# \"SUN\", \"Sun\", and \"sun\" are equally accepted."
	echo "# If no value is set, \`@daily\` will be used."
	echo "# If you do not want the cron to ever run, use \`0 0 5 31 2 ?\`."
	echo
	${BIN}/reconfigure_ask ${ENV_FILE} BACKUP_CRON_EXPRESSION "Enter the cron expression"
	echo
	${BIN}/reconfigure_ask ${ENV_FILE} BACKUP_RETENTION_DAYS "Rotate backups older than how many days?"
}

configure_remote() {
    DEFAULT=$(${BIN}/dotenv -f ${ENV_FILE} get BACKUP_STORAGE_TYPE)
    CHOSEN=$(wizard choose --default "${DEFAULT}" "Which remote storage do you want to use?" "s3" "ssh" "webdav" "azure" "dropbox" "local")
    ${BIN}/reconfigure ${ENV_FILE} BACKUP_STORAGE_TYPE="${CHOSEN}"
    case "$CHOSEN" in
        "s3")
            unconfigure_ssh
            unconfigure_azure
            unconfigure_dropbox
            unconfigure_webdav
            configure_s3
            configure_local_archive
            ;;
        "ssh")
            unconfigure_s3
            unconfigure_azure
            unconfigure_dropbox
            unconfigure_webdav
            configure_ssh
            configure_local_archive
            ;;
        "webdav")
            unconfigure_s3
            unconfigure_azure
            unconfigure_dropbox
            unconfigure_ssh
            configure_webdav
            configure_local_archive
            ;;
        "azure")
            unconfigure_s3
            unconfigure_ssh
            unconfigure_dropbox
            unconfigure_webdav
            configure_azure
            configure_local_archive
            ;;
        "dropbox")
            unconfigure_s3
            unconfigure_ssh
            unconfigure_azure
            unconfigure_webdav
            configure_dropbox
            configure_local_archive
            ;;
        "local")
            unconfigure_s3
            unconfigure_ssh
            unconfigure_azure
            unconfigure_webdav
            unconfigure_dropbox
            ${BIN}/reconfigure ${ENV_FILE} BACKUP_ARCHIVE=/archive
            ;;
        *)
            fault "Invalid choice."
            ;;
    esac
}

configure_local_archive() {
    echo
    BACKUP_ARCHIVE=$(${BIN}/dotenv -f ${ENV_FILE} get BACKUP_ARCHIVE)
    ${BIN}/confirm $(test -z "${BACKUP_ARCHIVE}" && echo no || echo yes) "Do you want to keep a local backup in addition to the remote one" "?" && ${BIN}/reconfigure ${ENV_FILE} BACKUP_ARCHIVE=/archive || ${BIN}/reconfigure ${ENV_FILE} BACKUP_ARCHIVE=""
}

unconfigure_s3() {
    echo "Unconfiguring S3 ..."
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_AWS_ENDPOINT
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_AWS_S3_BUCKET_NAME
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_AWS_ACCESS_KEY_ID
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_AWS_SECRET_ACCESS_KEY
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_AWS_S3_PATH
}

unconfigure_ssh() {
    echo "Unconfiguring SSH ..."
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_SSH_HOST_NAME
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_SSH_PORT
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_SSH_USER
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_SSH_REMOTE_PATH
}

unconfigure_azure() {
    echo "Unconfiguring Azure ..."
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_AZURE_STORAGE_CONTAINER_NAME
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_AZURE_STORAGE_ACCOUNT_NAME
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_AZURE_STORAGE_PRIMARY_ACCOUNT_KEY
}

unconfigure_dropbox() {
    echo "Unconfiguring Dropbox ..."
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_DROPBOX_REFRESH_TOKEN
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_DROPBOX_APP_KEY
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_DROPBOX_APP_SECRET
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_DROPBOX_REMOTE_PATH
}

unconfigure_webdav() {
    echo "Unconfiguring WebDAV ..."
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_WEBDAV_URL
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_WEBDAV_PATH
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_WEBDAV_USERNAME
    ${BIN}/reconfigure_dist ${ENV_FILE} BACKUP_WEBDAV_PASSWORD
}


configure_s3() {
    echo
	${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_AWS_ENDPOINT "Enter the S3 endpoint (e.g., s3.example.com)" 
	${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_AWS_S3_BUCKET_NAME "Enter the S3 bucket name (e.g., my-bucket)"
	${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_AWS_ACCESS_KEY_ID "Enter the S3 access key id (e.g., my-access-key)"
	${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_AWS_SECRET_ACCESS_KEY "Enter the S3 secret access key"
	ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_AWS_S3_PATH "Choose a directory inside the bucket (blank for root)"
}

configure_ssh() {
    echo
	${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_SSH_HOST_NAME "Enter the SSH hostname (e.g., ssh.example.com)" 
	${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_SSH_PORT "Enter the SSH port" 22
    ${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_SSH_USER "Enter the SSH user"
    ${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_SSH_REMOTE_PATH "Enter the SSH remote path"
}

configure_webdav() {
    echo
	${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_WEBDAV_URL "Enter the WebDAV URL (e.g., dav.example.com)" 
	${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_WEBDAV_PATH "Enter the WebDAV path" 
	${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_WEBDAV_USERNAME "Enter the WebDAV username" 
	${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_WEBDAV_PASSWORD "Enter the WebDAV password" 
}


configure_dropbox() {
    echo
	${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_DROPBOX_REFRESH_TOKEN "Enter the Dropbox refresh token" 
	${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_DROPBOX_APP_KEY "Enter the Dropbox app key" 
	${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_DROPBOX_APP_SECRET "Enter the Dropbox app secret" 
	${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_DROPBOX_REMOTE_PATH "Enter the Dropbox remote path" 
}

configure_azure() {
    echo
	${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_AZURE_STORAGE_CONTAINER_NAME "Enter the Azure storage container name"
    ${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_AZURE_STORAGE_ACCOUNT_NAME "Enter the Azure storage account name"
    ${BIN}/reconfigure_ask ${ENV_FILE} \
          BACKUP_AZURE_STORAGE_PRIMARY_ACCOUNT_KEY "Enter the Azure storage primary account key"
}

configure_notifications() {
    echo
    DEFAULT=$(${BIN}/dotenv -f ${ENV_FILE} get BACKUP_NOTIFICATION_TYPE)
    CHOSEN=$(wizard choose --default "${DEFAULT}" "Do you want to receive notifications for backup failure?" "No." "Yes, via email." "Yes, via webhook.")
    ${BIN}/reconfigure ${ENV_FILE} "BACKUP_NOTIFICATION_TYPE=${CHOSEN}"
    case "$CHOSEN" in
        "No.")
            ${BIN}/reconfigure ${ENV_FILE} "BACKUP_NOTIFICATION_URLS="
            ;;
        "Yes, via email.")
            ROOT_DOMAIN=$(${BIN}/dotenv -f ${ROOT_DIR}/${ROOT_ENV} get ROOT_DOMAIN)
            ask_no_blank "Enter the sender email address" SENDER_ADDRESS "${PROJECT_INSTANCE//_/\-}@${ROOT_DOMAIN}"
            ask_no_blank "Enter the recipient email address" RECIPIENT_ADDRESS
            ${BIN}/reconfigure ${ENV_FILE} "BACKUP_NOTIFICATION_URLS=smtp://postfix-relay-postfix-relay-1:587/?fromAddress=${SENDER_ADDRESS}&toAddresses=${RECIPIENT_ADDRESS}&useStartTLS=false"
            ;;
        "Yes, via webhook.")
            ask_no_blank "Enter the webhook URL" WEBHOOK_URL
            if [[ "$WEBHOOK_URL" != */ ]]; then
                WEBHOOK_URL="$WEBHOOK_URL/"
            fi
            WEBHOOK_URL="generic://${WEBHOOK_URL#https://}?template=json"
            ${BIN}/reconfigure ${ENV_FILE} "BACKUP_NOTIFICATION_URLS=${WEBHOOK_URL}"
            ;;
        *)
            fault "Invalid choice."
            ;;
    esac
}

setup() {
    source ../_scripts/funcs.sh
    set -e
    check_var ROOT_DIR ENV_FILE PROJECT_INSTANCE ROOT_ENV
    configure_backups
    configure_cron
    configure_remote
    configure_notifications
}

setup
