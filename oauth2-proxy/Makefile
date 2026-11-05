ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} OAUTH2_PROXY_HOST "Enter the oauth2-proxy host domain name" auth.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} OAUTH2_PROXY_COOKIE_DOMAIN "Enter the cookie domain name (ie ROOT domain)" ${ROOT_DOMAIN}
	@${BIN}/reconfigure_password ${ENV_FILE} OAUTH2_PROXY_COOKIE_SECRET 32
	@echo
	@ENV_FILE=${ENV_FILE} ROOT_DIR=${ROOT_DIR} bash ./configure_https_port.sh || true

	@echo
	@${BIN}/reconfigure_choose ${ENV_FILE} OAUTH2_PROXY_SELECTED_PROVIDER "Select the OIDC provider to use" "forgejo"
	@test "forgejo" == $$(${BIN}/dotenv -f ${ENV_FILE} get OAUTH2_PROXY_SELECTED_PROVIDER) && ENV_FILE=${ENV_FILE} ROOT_DIR=${ROOT_DIR} bash ./configure_forgejo.sh || true


.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=oauth2-proxy

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
