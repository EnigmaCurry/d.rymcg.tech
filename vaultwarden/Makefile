ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-no-open
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} VAULTWARDEN_TRAEFIK_HOST "Enter the vaultwarden domain name" vaultwarden${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} VAULTWARDEN_INSTANCE=$${instance:-default}
	@${BIN}/confirm yes "Would you like to set a base path to obfuscate the URL with an appended security string" "?" && ${BIN}/reconfigure_password ${ENV_FILE} VAULTWARDEN_BASE_PATH || ${BIN}/reconfigure ${ENV_FILE} VAULTWARDEN_BASE_PATH=''
	@test "$$(${BIN}/dotenv -f ${ENV_FILE} get VAULTWARDEN_SIGNUPS_ALLOWED)" == "true" && echo && echo "Warning: Public registration is enabled." && echo "After creating your first account, you may disable registration: \`make disable-registration\`." || true

.PHONY: enable-registration
enable-registration:
	@${BIN}/reconfigure ${ENV_FILE} VAULTWARDEN_SIGNUPS_ALLOWED=true
	@make --no-print-directory install

.PHONY: disable-registration
disable-registration:
	@${BIN}/reconfigure ${ENV_FILE} VAULTWARDEN_SIGNUPS_ALLOWED=false
	@make --no-print-directory install

.PHONY: open
open:
	@ENV_FILE=${ENV_FILE} CONTEXT_INSTANCE=${CONTEXT_INSTANCE} ${BIN}/open "/$$(dotenv -f ${ENV_FILE} get VAULTWARDEN_BASE_PATH)/"
