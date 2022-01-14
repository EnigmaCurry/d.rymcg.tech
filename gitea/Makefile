ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure whoami .env file
config:
	@${BIN}/reconfigure_ask GITEA_TRAEFIK_HOST "Enter the gitea domain name" "git.example.com"
	@${BIN}/reconfigure_ask APP_NAME "Enter service description" "git thing"
