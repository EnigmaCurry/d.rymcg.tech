ROOT_DIR = ..
include ../_scripts/Makefile.projects
include ../_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} CRYPTPAD_INSTANCE=${instance}
	@SUFFIX=$$(test -z "$${instance}" && echo "" || echo "-$${instance}"); ${BIN}/reconfigure_ask ${ENV_FILE} CRYPTPAD_TRAEFIK_HOST "Enter the main cryptpad domain name" pad$${SUFFIX}.${ROOT_DOMAIN}
	@SUFFIX=$$(test -z "$${instance}" && echo "" || echo "-$${instance}"); ${BIN}/reconfigure_ask ${ENV_FILE} CRYPTPAD_SANDBOX_DOMAIN "Enter the sandbox domain name" pad-sandbox$${SUFFIX}.${ROOT_DOMAIN}
	@echo ""
	@docker volume inspect ${PROJECT_INSTANCE}_config >/dev/null && ${BIN}/reconfigure_ask ${ENV_FILE} CRYPTPAD_ADMIN_KEY "Enter your admin account public signing key" "-" && ${BIN}/reconfigure_ask ${ENV_FILE} CRYPTPAD_ADMIN_EMAIL "If you want to offer your support to your users, enter an email address" "-" || echo -e "That's expected, if this is the first time you're installing cryptpad.\nFinish installation and create the admin account:\n  make install\n  make open        # Your browser should open to the application page.\nClick \`Sign up\` and register for a new account.\nOnce logged in, click on your username in the upper right corner, and select \`Settings\`.\nCopy your account's Public Signing Key.\nNext re-run:\n  make config     # Enter your Public Signing Key when asked.\n  make install\nLogin again and find all the admin functions in the \`Administration\` menu."

.PHONY: shell
shell:
	make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="exec -it cryptpad sh"
