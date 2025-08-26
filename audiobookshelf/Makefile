ROOT_DIR = ${HOME}/git/vendor/enigmacurry/d.rymcg.tech
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} AUDIOBOOKSHELF_TRAEFIK_HOST "Enter the website domain name" audiobookshelf${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} AUDIOBOOKSHELF_INSTANCE=${instance}
	@${BIN}/reconfigure_auth ${ENV_FILE} AUDIOBOOKSHELF
	@echo ""

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:audiobookshelf instance=@AUDIOBOOKSHELF_INSTANCE traefik_host=@AUDIOBOOKSHELF_TRAEFIK_HOST http_auth=AUDIOBOOKSHELF_HTTP_AUTH http_auth_var=@AUDIOBOOKSHELF_HTTP_AUTH ip_sourcerange=@AUDIOBOOKSHELF_IP_SOURCERANGE oauth2=AUDIOBOOKSHELF_OAUTH2 authorized_group=AUDIOBOOKSHELF_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=AUDIOBOOKSHELF_MTLS_AUTH mtls_authorized_certs=AUDIOBOOKSHELF_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=audiobookshelf

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
