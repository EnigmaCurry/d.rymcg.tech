ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} PLAUSIBLE_TRAEFIK_HOST "Enter the plausible domain name" plausible${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_password ${ENV_FILE} PLAUSIBLE_SECRET_KEY_BASE 64
	@${BIN}/reconfigure_password ${ENV_FILE} PLAUSIBLE_POSTGRES_PASSWORD 32
	@${BIN}/reconfigure_ask ${ENV_FILE} PLAUSIBLE_DISABLE_REGISTRATION "Should registration be disabled?: (Enter \`true\`, \`false\`, or \`invite_only\`)" invite_only

.PHONY: shell
shell:
	@container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'mail' 'db' 'events_db' 'app' --default 'app'") && make --no-print-directory docker-compose-shell SERVICE=$${container}
