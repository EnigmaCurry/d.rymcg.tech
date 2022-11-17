ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} JITSIMEET_TRAEFIK_HOST "Enter the Jitsi Meet domain" meet.${ROOT_DOMAIN}
	@${BIN}/confirm yes "Would you like to require authentication to become a meeting host" "?" && ${BIN}/reconfigure ${ENV_FILE} ENABLE_AUTH=1 AUTH_TYPE=internal && ${BIN}/confirm yes "Would you like to allow guests" "?" && ${BIN}/reconfigure ${ENV_FILE} ENABLE_GUESTS=1 || true
	@${BIN}/reconfigure ${ENV_FILE} PUBLIC_URL=https://$$(${BIN}/dotenv -f ${ENV_FILE} get JITSIMEET_TRAEFIK_HOST) JICOFO_AUTH_PASSWORD=$$(openssl rand -hex 24) JVB_AUTH_PASSWORD=$$(openssl rand -hex 24) JIGASI_XMPP_PASSWORD=$$(openssl rand -hex 24) JIBRI_RECORDER_PASSWORD=$$(openssl rand -hex 24) JIBRI_XMPP_PASSWORD=$$(openssl rand -hex 24) DOCKER_HOST_ADDRESS=$$(${BIN}/dotenv -f ../traefik/${ENV_FILE} get TRAEFIK_PROXY_SUBNET_IP)


.PHONY: user # Create a user account
user:
	@source ${BIN}/funcs.sh && ask "Enter the username to create" USERNAME && PASSWORD=$$(openssl rand -hex 24) && echo "Password: $${PASSWORD}" && docker compose --env-file ${ENV_FILE} exec prosody prosodyctl --config /config/prosody.cfg.lua register "$${USERNAME}" meet.jitsi "$${PASSWORD}"

.PHONY: user-list # List of user accounts
user-list:
	@docker compose --env-file ${ENV_FILE} exec prosody find /config/data/meet%2ejitsi/accounts -type f -exec basename {} .dat \;
