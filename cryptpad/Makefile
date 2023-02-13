ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} CRYPTPAD_INSTANCE=${instance}
	@${BIN}/reconfigure_ask ${ENV_FILE} CRYPTPAD_TRAEFIK_HOST "Enter the main cryptpad domain name" pad${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} CRYPTPAD_SANDBOX_DOMAIN "Enter the sandbox domain name" pad-sandbox${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} CRYPTPAD_HTTP_AUTH default=no
	@echo ""
	@docker volume inspect ${PROJECT_INSTANCE}_config >/dev/null && ${BIN}/reconfigure_ask ${ENV_FILE} CRYPTPAD_ADMIN_KEY "Enter your admin account public signing key" "-" && ${BIN}/reconfigure_ask ${ENV_FILE} CRYPTPAD_ADMIN_EMAIL "If you want to offer your support to your users, enter an email address" "-" || echo -e "That's expected, if this is the first time you're installing cryptpad.\nFinish installation and create the admin account:\n  make install\n  make open        # Your browser should open to the application page.\nClick \`Sign up\` and register for a new account.\nOnce logged in, click on your username in the upper right corner, and select \`Settings\`.\nCopy your account's Public Signing Key.\nAfterwards, re-run:\n  make config     # Enter your Public Signing Key when asked.\n  make install\nLogin again and find all the admin functions in the \`Administration\` menu."

.PHONY: shell
shell:
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -it cryptpad bash"

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:cryptpad instance=@CRYPTPAD_INSTANCE traefik_host=@CRYPTPAD_TRAEFIK_HOST cryptpad_sandbox_domain=@CRYPTPAD_SANDBOX_DOMAIN http_auth=CRYPTPAD_HTTP_AUTH http_auth_var=@CRYPTPAD_HTTP_AUTH ip_sourcerange=@CRYPTPAD_IP_SOURCERANGE
