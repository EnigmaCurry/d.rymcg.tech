ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

# .PHONY: config-hook
# config-hook:
# 	@${BIN}/reconfigure_ask ${ENV_FILE} GITEA_TRAEFIK_HOST "Enter the gitea domain name (eg. git.example.com)"

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=matterbridge