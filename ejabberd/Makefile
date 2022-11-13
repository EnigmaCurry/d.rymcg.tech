ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook # Configure .env file
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} EJABBERD_HOST=xmpp.${ROOT_DOMAIN} CERTIFICATE_VOLUME=${ROOT_DOMAIN}_certificate-ca_xmpp.${ROOT_DOMAIN}

