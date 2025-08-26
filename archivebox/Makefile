ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} ARCHIVEBOX_INSTANCE=${instance}
	@${BIN}/reconfigure_ask ${ENV_FILE} ARCHIVEBOX_TRAEFIK_HOST "Enter the archivebox domain name" archivebox${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} SECRET_KEY=$$(openssl rand -hex 45)
	@${BIN}/reconfigure ${ENV_FILE} ARCHIVEBOX_USERNAME=admin
	@${BIN}/reconfigure ${ENV_FILE} ARCHIVEBOX_EMAIL=admin@localhost
	@${BIN}/reconfigure ${ENV_FILE} ARCHIVEBOX_PASSWORD=$$(openssl rand -hex 30)
	@${BIN}/reconfigure_auth ${ENV_FILE} ARCHIVEBOX

.PHONY: admin # Create admin account
admin:
	@docker compose --env-file=${ENV_FILE} exec archivebox su -c "DJANGO_SUPERUSER_PASSWORD=$$(${BIN}/dotenv -f ${ENV_FILE} get ARCHIVEBOX_PASSWORD) archivebox manage createsuperuser --noinput --username $$(${BIN}/dotenv -f ${ENV_FILE} get ARCHIVEBOX_USERNAME) --email $$(${BIN}/dotenv -f ${ENV_FILE} get ARCHIVEBOX_EMAIL)" archivebox

.PHONY: api-dev
api-dev:
	make build
	@docker-compose --env-file=${ENV_FILE} stop public-api-gateway
	@docker-compose --env-file=${ENV_FILE} run --rm public-api-gateway

.PHONY: schedule-show # Print a list of currently active ArchiveBox cron jobs
schedule-show:
	@docker compose --env-file=${ENV_FILE} exec archivebox su -c "/usr/local/bin/archivebox schedule --show" archivebox

.PHONY: schedule-add # Add a new scheduled ArchiveBox update job to cron
schedule-add:
	@URL=$$(${BIN}/ask_echo "Enter the URL to snapshot on this schedule") && \
		SCHEDULE=$$(${BIN}/ask_echo "Snapshot should run every... (\"hour\", \"day\", \"month\", \"year\", or cron format like \"0 0 * * *\")") \
		OPTIONS=("1" "0") \
		PROMPT="Select the depth of the snapshot" \
		DEPTH=$$(eval ${BIN}/script-wizard choose $${PROMPT@Q} $${OPTIONS[@]@Q} --default "0") \
		TAG_RESPONSE=$$(${BIN}/ask_echo_blank "Enter a comma-separated list of tags to attach to the snapshot (or leave blank)") && \
		if [[ -n $${TAG_RESPONSE} ]]; then \
			TAG="--tag=$${TAG_RESPONSE}"; \
		else \
			TAG=""; \
		fi && \
		OPTIONS=("overwrite" "add new") \
		PROMPT="Overwrite previous snapshot or add new snapshot each time" \
		DEFAULT="add new" \
		OVERWRITE_RESPONSE=$$(eval ${BIN}/script-wizard choose $${PROMPT@Q} $${OPTIONS[@]@Q} --default $${DEFAULT@Q}) && \
		if [[ $${OVERWRITE_RESPONSE} == "overwrite" ]]; then \
			OVERWRITE="--overwrite"; \
		else \
			OVERWRITE=""; \
		fi && \
		docker compose --env-file=${ENV_FILE} exec archivebox su -c "/usr/local/bin/archivebox schedule --add --every=\"$${SCHEDULE}\" --depth=$${DEPTH} $${TAG} $${OVERWRITE} \"$${URL}\"" archivebox

.PHONY: schedule-help # Show help for scheduling commands
schedule-help:
	@echo "Archivebox can automatically snapshot URLs on a schedule, but you can only manage those schedule via the Archivebox CLI. These makefile targets cover most of the scheduling functions."
	@echo " - make schedule-add        - Add a new scheduled ArchiveBox update job to cron"
	@echo " - make schedule-clear      - Stop all ArchiveBox scheduled runs (remove cron jobs)"
	@echo " - make schedule-help       - Show help for scheduling commands"
	@echo " - make schedule-overwrite  - Re-archive any URLs that have been previously archived, overwriting existing Snapshots"
	@echo " - make schedule-show       - Print a list of currently active ArchiveBox cron jobs"
	@echo " - make schedule-update     - Re-pull any URLs that have been previously added, as needed to fill missing ArchiveResults"
	@echo
	@echo "You can also enter a shell on the container (\`make shell\` and select \"archivebox\") and use the \`archivebox schedule\` command manually:"
	@docker compose --env-file=${ENV_FILE} exec archivebox su -c "/usr/local/bin/archivebox schedule --help" archivebox
	@echo
	@echo
	@echo "Learn more about scheduling in Archivebox here: https://github.com/ArchiveBox/ArchiveBox/wiki/Scheduled-Archiving"
	@echo

.PHONY: schedule-clear # Stop all ArchiveBox scheduled runs (remove cron jobs)
schedule-clear:
	@docker compose --env-file=${ENV_FILE} exec archivebox su -c "/usr/local/bin/archivebox schedule --clear" archivebox

.PHONY: schedule-overwrite # Re-archive any URLs that have been previously archived, overwriting existing Snapshots
schedule-overwrite:
	@docker compose --env-file=${ENV_FILE} exec archivebox su -c "/usr/local/bin/archivebox schedule --overwrite" archivebox

.PHONY: schedule-update # Re-pull any URLs that have been previously added, as needed to fill missing ArchiveResults
schedule-update:
	@docker compose --env-file=${ENV_FILE} exec archivebox su -c "/usr/local/bin/archivebox schedule --update" archivebox

.PHONY: schedule-run-all # Run all the scheduled jobs once immediately, independent of their configured schedules
schedule-run-all:
	@docker compose --env-file=${ENV_FILE} exec archivebox su -c "/usr/local/bin/archivebox schedule --run-all" archivebox

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:archivebox instance=@ARCHIVEBOX_INSTANCE traefik_host=@ARCHIVEBOX_TRAEFIK_HOST http_auth=ARCHIVEBOX_HTTP_AUTH http_auth_var=@ARCHIVEBOX_HTTP_AUTH ip_sourcerange=@ARCHIVEBOX_IP_SOURCERANGE oauth2=ARCHIVEBOX_OAUTH2 authorized_group=ARCHIVEBOX_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=ARCHIVEBOX_MTLS_AUTH mtls_authorized_certs=ARCHIVEBOX_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'archivebox' 'public-api-gateway' --default 'archivebox'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: install-hook
install-hook:
	@echo
