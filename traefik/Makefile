ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-no-open

.PHONY: config-hook
config-hook: config-menu config-domain compose-profiles 
	@echo ""
	@echo 'Base configuration complete.'
	@echo 'Run `make certs` to configure certificate domains.'
	@echo "Examine the environment file: ${ENV_FILE}"
	@echo 'Then run `make install` to (re)install.'

.PHONY: config-menu
config-menu:
	@ENV_FILE=${ENV_FILE} ./setup.sh main_menu || true

.PHONY: config-domain
config-domain:
	@${BIN}/reconfigure ${ENV_FILE} TRAEFIK_ROOT_DOMAIN=${ROOT_DOMAIN}

.PHONY: config-dashboard
config-dashboard:
	@${BIN}/reconfigure_dashboard ${ENV_FILE}

.PHONY: config-acme
config-acme:
	@${BIN}/reconfigure_acme ${ENV_FILE}

.PHONY: config-error-pages
config-error-pages:
	@TRAEFIK_ERROR_PAGES_TEMPLATE="$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_ERROR_PAGES_TEMPLATE)"; ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_ERROR_PAGES_TEMPLATE="$$(${BIN}/script-wizard choose --default $${TRAEFIK_ERROR_PAGES_TEMPLATE:-l7-light}  'Select an error page theme (https://github.com/tarampampam/error-pages#-templates)' ghost l7-light l7-dark shuffle noise hacker-terminal cats lost-in-space app-down connection matrix orient)"

.PHONY: config-middleware
config-middleware:
	@${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_PLUGIN_MAXMIND_GEOIP) == "true" ]] && echo "yes" || echo "no") "Do you want to enable the MaxMind GeoIP client locator plugin" "?" && ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_PLUGIN_MAXMIND_GEOIP=true || ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_PLUGIN_MAXMIND_GEOIP=false || true
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_PLUGIN_MAXMIND_GEOIP) == "true" ]] && echo "You may create a free MaxMind account: https://www.maxmind.com/en/geolite2/signup" && echo "Login to your MaxMind account and create a License Key." && echo "" && ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_GEOIPUPDATE_ACCOUNT_ID "Enter your MaxMind account ID" && ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_GEOIPUPDATE_LICENSE_KEY "Enter your MaxMind license key" && ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_GEOIPUPDATE_EDITION_IDS "Enter the GeoIP database IDs you wish to install" "GeoLite2-ASN GeoLite2-City GeoLite2-Country" || true

.PHONY: config-wireguard
config-wireguard:
	@${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENABLED) == "true" ]] && echo "yes" || echo "no") "Do you want to run Traefik exclusively inside a VPN (wireguard server mode)" "?" && make --no-print-directory config-wireguard-server || ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_ENABLED=false || true
	@echo ""
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENABLED) != "true" ]] && ${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_CLIENT_ENABLED) == "true" ]] && echo "yes" || echo "no") "Do you want to run Traefik as a reverse proxy for an external VPN (wireguard client mode)" "?" && make --no-print-directory config-wireguard-client || ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_CLIENT_ENABLED=false || true
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENABLED) != "true" ]] && [[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_CLIENT_ENABLED) != "true" ]] && ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_NETWORK_MODE=host TRAEFIK_DASHBOARD_ENTRYPOINT_HOST=127.0.0.1 || true

.PHONY: config-wireguard-server
config-wireguard-server:
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_HOST "Enter the public Traefik VPN hostname" vpn.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_ROOT_DOMAIN=${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_SUBNET "Enter the Traefik VPN private subnet (no mask)"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_ADDRESS "Enter the Traefik VPN private IP address" 10.13.16.1
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_PORT "Enter the Traefik VPN TCP port number"
	@${BIN}/reconfigure_ask_multi ${ENV_FILE} TRAEFIK_WEB_ENTRYPOINT_HOST,TRAEFIK_WEBSECURE_ENTRYPOINT_HOST,TRAEFIK_MQTT_ENTRYPOINT_HOST,TRAEFIK_SSH_ENTRYPOINT_HOST "Enter the Traefik VPN IP address to bind all the entrypoints to" 10.13.16.1
	@${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_ENABLED=true TRAEFIK_NETWORK_MODE=service:wireguard TRAEFIK_VPN_ALLOWED_IPS=$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_SUBNET)/24 TRAEFIK_DASHBOARD_ENTRYPOINT_HOST="0.0.0.0"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_PEERS "Enter the Traefik VPN peers list"
	@make --no-print-directory compose-profiles

.PHONY: config-wireguard-client
config-wireguard-client:
	@echo ""
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_ROOT_DOMAIN "Enter the ROOT_DOMAIN used by the server config"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_PEER_SERVICES "Enter the list of VPN service names that the client should reverse proxy (comma separated; hostnames only)" whoami
	@echo "Scan the QR code for the client credentials printed in the wireguard server's log. Copy the details from the decoded QR code (The first line should be: [Interface]):"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_INTERFACE_ADDRESS "Enter the wireguard client Interface Address"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_INTERFACE_PRIVATE_KEY "Enter the wireguard PrivateKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_INTERFACE_LISTEN_PORT "Enter the wireguard listen port" 51820
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_INTERFACE_PEER_DNS "Enter the wireguard Interface DNS" 10.13.16.1
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_PEER_PUBLIC_KEY "Enter the Peer PublicKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_PEER_PRESHARED_KEY "Enter the Peer PresharedKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_PEER_ENDPOINT "Enter the Peer Endpoint (host:port)"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_PEER_ALLOWED_IPS "Enter the Peer AllowedIPs"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_ADDRESS "Enter the Traefik VPN private IP address" 10.13.16.1
	@${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_CLIENT_ENABLED=true TRAEFIK_NETWORK_MODE=service:wireguard-client TRAEFIK_DASHBOARD_ENTRYPOINT_HOST="0.0.0.0"

	@make --no-print-directory compose-profiles

.PHONY: open # Start SSH tunnel and open the Traefik Dashboard
open:
	@export ENV_FILE=${ENV_FILE} CONTEXT_INSTANCE=${CONTEXT_INSTANCE} PORT_FORWARD="$$(${BIN}/port_forward ${ENV_FILE} traefik 127.0.0.1:8080)"; if [[ ! "$${PORT_FORWARD}" =~ [0-9]+ ]]; then ${BIN}/fault "Could not get the SSH forwarded port"; else ${BIN}/open /dashboard/#/http/routers 127.0.0.1:$${PORT_FORWARD} http; fi;

.PHONY: close # Stop the dashboard SSH tunnel
close:
	pkill -f "^ssh -N -L 8080:localhost:8080 ssh.${ROOT_DOMAIN}"

.PHONY: cert
cert: certs

.PHONY: certs # Make TLS Certificates
certs:
	@${BIN}/reconfigure_certs ${ENV_FILE}

.PHONY: config-inspect # Inspect the live configuration
config-inspect:
	@docker-compose --env-file ${ENV_FILE} exec traefik sh -c "find /data/config -type f | xargs -iXX sh -c \"echo \#\! XX && cat XX && echo ''\""

.PHONY: shell
shell:
	@container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'traefik' 'geoip_database' 'wireguard' 'wireguard-client' --default 'traefik'") && make --no-print-directory docker-compose-shell SERVICE=$${container}

.PHONY: shell-root
shell-root:
	docker compose --env-file=${ENV_FILE} exec --user root -it traefik /bin/sh

.PHONY: show-wireguard-peers
show-wireguard-peers:
	docker compose --env-file=${ENV_FILE} exec -it wireguard /bin/sh -c 'ls /config/peer*/*.conf | xargs -iXX sh -c "echo && echo \#\#\ XX && cat XX"'

.PHONY: show-wireguard-peers-qr
show-wireguard-peers-qr:
	docker compose --env-file=${ENV_FILE} exec -it wireguard /bin/sh -c 'ls /config/peer*/*.conf | xargs -iXX sh -c "echo && echo \#\#\ XX && qrencode -t ansiutf8 < XX"'

.PHONY: compose-profiles
compose-profiles:
	@${BIN}/reconfigure_compose_profiles ${ENV_FILE} TRAEFIK_PLUGIN_MAXMIND_GEOIP=geoip_update TRAEFIK_VPN_ENABLED=wireguard TRAEFIK_VPN_CLIENT_ENABLED=wireguard-client

.PHONY: wireguard-reset
wireguard-reset:
	docker compose --env-file=${ENV_FILE} exec -it wireguard wg-quick down wg0

.PHONY: destroy-wireguard
destroy-wireguard:
	@docker-compose --env-file ${ENV_FILE} --profile wireguard down -v

.PHONY: logs-traefik # Tail the Traefik logs
logs-traefik:
	@docker-compose --env-file ${ENV_FILE} --profile default logs -f

.PHONY: logs-access # Tail the access logs
logs-access:
	@docker-compose --env-file ${ENV_FILE} --profile default exec -it traefik sh -c 'tail -f /data/access.log | jq'

.PHONY: debug # Restart Traefik with debug logging for one time only
debug:
	@EXISTING_TRAEFIK_LOG_LEVEL=$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LOG_LEVEL) && ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_LOG_LEVEL=debug && make --no-print-directory install; STARTED=$$?; ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_LOG_LEVEL=$${EXISTING_TRAEFIK_LOG_LEVEL} && [[ "$$STARTED" == "0" ]] && make --no-print-directory logs-traefik

.PHONY: sentry
sentry:
	@make --no-print-directory -C "${ROOT_DIR}" script-wizard
	@${BIN}/reconfigure_header_authorization ${ENV_FILE}

.PHONY: sentry-callback
sentry-callback:
	@${BIN}/reconfigure_header_authorization ${ENV_FILE} list-callback-urls
