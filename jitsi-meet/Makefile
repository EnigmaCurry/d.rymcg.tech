ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} JITSIMEET_TRAEFIK_HOST "Enter the Jitsi Meet domain" meet.${ROOT_DOMAIN}
	@${BIN}/confirm yes "Would you like to require authentication to become a meeting host" "?" && ${BIN}/reconfigure ${ENV_FILE} ENABLE_AUTH=1 AUTH_TYPE=internal && ${BIN}/confirm yes "Would you like to allow guests" "?" && ${BIN}/reconfigure ${ENV_FILE} ENABLE_GUESTS=1 || true
	@${BIN}/reconfigure_ask ${ENV_FILE} TURNS_HOST "Enter your TURN (coturn) server host name"
	@${BIN}/reconfigure_ask ${ENV_FILE} TURNS_PORT "Enter your TURN (coturn) server port number"
	@${BIN}/reconfigure_ask ${ENV_FILE} TURN_CREDENTIALS "Enter your TURN (coturn) secret key"
	@${BIN}/reconfigure_password ${ENV_FILE} JICOFO_AUTH_PASSWORD
	@${BIN}/reconfigure_password ${ENV_FILE} JICOFO_AUTH_PASSWORD
	@${BIN}/reconfigure_password ${ENV_FILE} JIBRI_RECORDER_PASSWORD
	@${BIN}/reconfigure_password ${ENV_FILE} JIGASI_XMPP_PASSWORD
	@${BIN}/reconfigure_password ${ENV_FILE} JVB_AUTH_PASSWORD
	@${BIN}/reconfigure ${ENV_FILE} PUBLIC_URL=https://$$(${BIN}/dotenv -f ${ENV_FILE} get JITSIMEET_TRAEFIK_HOST)
	@TRAEFIK_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get JITSIMEET_TRAEFIK_HOST); ${BIN}/reconfigure ${ENV_FILE} JVB_ADVERTISE_IPS=$$(curl -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=$${TRAEFIK_HOST}&type=A" | jq -r ".Answer[0].data")

.PHONY: user # Create a user account
user:
	@source ${BIN}/funcs.sh && ask "Enter the username to create" USERNAME && PASSWORD=$$(openssl rand -hex 24) && echo "Password: $${PASSWORD}" && docker compose --env-file ${ENV_FILE} exec prosody prosodyctl --config /config/prosody.cfg.lua register "$${USERNAME}" meet.jitsi "$${PASSWORD}"

.PHONY: user-list # List of user accounts
user-list:
	@docker compose --env-file ${ENV_FILE} exec prosody find /config/data/meet%2ejitsi/accounts -type f -exec basename {} .dat \;

.PHONY: user-delete # Delete a user account
user-delete:
	@users="$$(make --no-print-directory user-list)" && \
	username="$$(eval "${BIN}/script-wizard choose 'Select the username to delete' $$(echo $$users | tr '\n' ' ')")" && \
	docker compose --env-file ${ENV_FILE} exec prosody prosodyctl --config /config/prosody.cfg.lua unregister "$$username" meet.jitsi

.PHONY: shell # Enter container shell
shell:
	@container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'web' 'prosody' 'jicofo' 'jvb' --default 'web'") && make --no-print-directory docker-compose-shell SERVICE=$${container}
