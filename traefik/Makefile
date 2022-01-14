ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure Traefik .env file
config:
	@echo "Let's Encrypt will helpfully email you when your certificates are about to expire."
	@${BIN}/reconfigure_ask ACME_CA_EMAIL "Enter your email address for Let's Encrypt (blank to skip)" asdf@asdf.net

