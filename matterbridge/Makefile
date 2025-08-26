ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

# .PHONY: config-hook
# config-hook:
# 	@${BIN}/reconfigure_ask ${ENV_FILE} FORGEJO_TRAEFIK_HOST "Enter the forgejo domain name (eg. git.example.com)"

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=matterbridge

.PHONY: install-hook
install-hook:
	@echo
