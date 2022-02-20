ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} CRYPTPAD_TRAEFIK_HOST "Enter the main cryptpad domain name" pad.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} CRYPTPAD_SANDBOX_DOMAIN "Enter the sandbox domain name" pad.box.${ROOT_DOMAIN}
	@echo ""
	@echo "Skip this next part if this if this is the initial install (rerun this again after account creation):"
	@${BIN}/reconfigure_ask ${ENV_FILE} ADMIN_KEY "Enter your admin account public signing key"
	@${BIN}/reconfigure_ask ${ENV_FILE} ADMIN_EMAIL "If you want to offer your support to your users, enter an email address:"
