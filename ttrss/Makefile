ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask TTRSS_TRAEFIK_HOST "Enter the ttrss domain name" tt-rss.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask TTRSS_SELF_URL_PATH "Enter the ttrss self url" "https://tt-rss.${ROOT_DOMAIN}/tt-rss"

