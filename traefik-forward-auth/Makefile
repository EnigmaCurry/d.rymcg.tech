ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure whoami .env file
config:
	@${BIN}/reconfigure_ask GITEA_TRAEFIK_HOST "Enter the gitea domain name (eg. git.example.com)"
