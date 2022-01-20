ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask FRESHRSS_TRAEFIK_HOST "Enter the ttrss domain name" freshrss.${ROOT_DOMAIN}

