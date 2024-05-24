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
	@container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'archivebox' 'public-api-gateway' --default 'archivebox'") && make --no-print-directory docker-compose-shell SERVICE=$${container}
