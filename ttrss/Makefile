ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask TTRSS_TRAEFIK_HOST "Enter the ttrss domain name" ttrss.${ROOT_DOMAIN}

