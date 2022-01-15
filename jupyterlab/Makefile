ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask JUPYTERLAB_TRAEFIK_HOST "Enter the jupyterlab domain name" jupyterlab.${ROOT_DOMAIN}
