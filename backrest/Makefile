ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} BACKREST_TRAEFIK_HOST "Enter the backrest domain name" backrest${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} BACKREST_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} BACKREST
	@echo
	@echo "Backrest restores files to a path in the container. In order to retrieve restored files to your local computer, you can configure a named Docker volume and then copy restored files from the volume's path on the host (e.g., \`/var/lib/docker/volumes/backrest_<volume-name>/_data/\`) to your local computer using \`docker cp\`, \`rsync\`, etc. Or you can configure a bind mount on the host (e.g., \`/mnt/restored-files\` on the host might be an NFS share that you have access to from your local computer, so you can configure \`/mnt/restored-files\` as a bind mount in the Backrest container and Backrest will restore files directly to the NFS share that you can access from your local computer)."
	@choices=('bind mount' 'Docker volume'); \
		[[ "$$(${BIN}/dotenv -f ${ENV_FILE} get BACKREST_USE_EXTERNAL_VOLUME)" == "false" ]] && default='Docker volume' || default='bind mount'; \
		answer=$$(eval "${BIN}/script-wizard choose 'Select whether you want Backrest to restore files to a bind mount on the host or to a named Docker volume' $${choices[@]@Q} --default '$$default'"); \
		if [ "$$answer" = "bind mount" ]; then \
			${BIN}/reconfigure ${ENV_FILE} BACKREST_USE_EXTERNAL_VOLUME=true; \
			ALLOW_BLANK=0 ${BIN}/reconfigure_ask ${ENV_FILE} BACKREST_EXTERNAL_VOLUME "Enter the path on the host where you want Backrest to restore files to (e.g., \"/mnt/backrest-restores\")." $$(${BIN}/dotenv -f "${ENV_FILE}" get "BACKREST_EXTERNAL_VOLUME"); \
		else \
			${BIN}/reconfigure ${ENV_FILE} BACKREST_USE_EXTERNAL_VOLUME=false; \
		fi
	@echo 

.PHONY: override-hook
override-hook:
#### This sets the override template variables for docker-compose.instance.yaml:
#### The template dynamically renders to docker-compose.override_{DOCKER_CONTEXT}_{INSTANCE}.yaml
#### These settings are used to automatically generate the service container labels, and traefik config, inside the template.
#### The variable arguments have three forms: `=` `=:` `=@`
####   name=VARIABLE_NAME    # sets the template 'name' field to the value of VARIABLE_NAME found in the .env file
####                         # (this hardcodes the value into docker-compose.override.yaml)
####   name=:VARIABLE_NAME   # sets the template 'name' field to the literal string 'VARIABLE_NAME's
####                         # (this hardcodes the string into docker-compose.override.yaml)
####   name=@VARIABLE_NAME   # sets the template 'name' field to the literal string '${VARIABLE_NAME}'
####                         # (used for regular docker-compose expansion of env vars by name.)
	@${BIN}/docker_compose_override ${ENV_FILE} project=:backrest instance=@BACKREST_INSTANCE traefik_host=@BACKREST_TRAEFIK_HOST http_auth=BACKREST_HTTP_AUTH http_auth_var=@BACKREST_HTTP_AUTH ip_sourcerange=@BACKREST_IP_SOURCERANGE oauth2=BACKREST_OAUTH2 authorized_group=BACKREST_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=BACKREST_MTLS_AUTH mtls_authorized_certs=BACKREST_MTLS_AUTHORIZED_CERTS use_external_volume=BACKREST_USE_EXTERNAL_VOLUME upload_location=BACKREST_EXTERNAL_VOLUME traefik_entrypoint=BACKREST_TRAEFIK_ENTRYPOINT

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=backrest

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
