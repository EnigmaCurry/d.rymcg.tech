ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} FRIGATE_TRAEFIK_HOST "Enter the frigate domain name" frigate${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} FRIGATE_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} FRIGATE
	@echo
	@${BIN}/reconfigure_password ${ENV_FILE} FRIGATE_RTSP_PASSWORD 32
	@echo

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:frigate instance=@FRIGATE_INSTANCE traefik_host=@FRIGATE_TRAEFIK_HOST http_auth=FRIGATE_HTTP_AUTH http_auth_var=@FRIGATE_HTTP_AUTH ip_sourcerange=@FRIGATE_IP_SOURCERANGE oauth2=FRIGATE_OAUTH2 authorized_group=FRIGATE_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=FRIGATE_MTLS_AUTH mtls_authorized_certs=FRIGATE_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=frigate

.PHONY: show-admin-user # Show the automatically-generated admin login credentials
show-admin-user:
	@echo
	@docker logs frigate-frigate-1 2>&1 | grep -F '***'
	@echo

.PHONY: disable-tls # Disable TLS on Frigate's webserver
disable-tls:
## Improvement would be to only insert the following configs if they haven't already been inserted.
	@echo
	@docker exec frigate-frigate-1 sh -c "printf '\ntls:\n    enabled: false\n\nauth:\n    enabled: true\n    trusted_proxies: [$$(${BIN}/dotenv -f ${ENV_FILE} get FRIGATE_TRUSTED_PROXIES)]\n\n' >> /config/config.yaml" && \
		echo "Disabled TLS on Frigate's webserver" || \
		(echo "Error: Failed to disable TLS on Frigate's webserver" && echo && exit 1)
	@echo
	@echo "Restarting container..." && sleep 1
	@make restart && echo && echo "Restarted container" || echo "Error: Failed to restart container"
	@echo
