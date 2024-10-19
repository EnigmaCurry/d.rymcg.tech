ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} SYSBOX_SYSTEMD_TRAEFIK_HOST "Enter the service domain name" $${INSTANCE:-my-service}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} SYSBOX_SYSTEMD_INSTANCE=$${instance:-default}

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:sysbox-systemd instance=@SYSBOX_SYSTEMD_INSTANCE traefik_host=@SYSBOX_SYSTEMD_TRAEFIK_HOST http_auth=SYSBOX_SYSTEMD_HTTP_AUTH http_auth_var=@SYSBOX_SYSTEMD_HTTP_AUTH ip_sourcerange=@SYSBOX_SYSTEMD_IP_SOURCERANGE ports=SYSBOX_SYSTEMD_PUBLIC_PORTS privileged=SYSBOX_PRIVILEGED

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=linux
