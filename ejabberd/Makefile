ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} EJABBERD_HOST=xmpp.${ROOT_DOMAIN} CERTIFICATE_VOLUME=${ROOT_DOMAIN}_certificate-ca_xmpp.${ROOT_DOMAIN}

