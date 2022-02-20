ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure ${ENV_FILE} EJABBERD_HOST=xmpp.${ROOT_DOMAIN} CERTIFICATE_VOLUME=${ROOT_DOMAIN}_certificate-ca_xmpp.${ROOT_DOMAIN}

