ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure whoami .env file
config:
	@${BIN}/reconfigure_ask WHOAMI_TRAEFIK_HOST "Enter the whoami domain name" whoami.${ROOT_DOMAIN}
