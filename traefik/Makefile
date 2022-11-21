ROOT_DIR = ..
include ../_scripts/Makefile.projects-no-open

## TODO: delete this, because we don't need a specific vpn network anymore..
# .PHONY: network # Create Docker networks
# network:
# 	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENTRYPOINT_ENABLED) == "true" ]] && (docker network inspect traefik-vpn >/dev/null 2>&1 || (echo "" && echo "Creating traefik-vpn network ..." && docker network create traefik-vpn --subnet "$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_SUBNET)" || true)) && echo "" && echo "Traefik VPN network:" && docker network ls | grep traefik-vpn && docker network inspect traefik-vpn | grep Subnet && echo "Traefik VPN entrypoint: $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENTRYPOINT_HOST):$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENTRYPOINT_PORT)" || true

.PHONY: config-hook
config-hook: traefik-user config-ask compose-profiles 
	@echo ""
	@echo 'Base configuration complete.'
	@echo 'Run `make certs` to configure certificate domains.'
	@echo "Examine the environment file: ${ENV_FILE}"
	@echo 'Then run `make install` to (re)install.'

.PHONY: traefik-user
traefik-user:
	@SSH_HOST=$$(docker context inspect | jq -r ".[0].Endpoints.docker.Host"); SSH_UID=$$(ssh $${SSH_HOST} id -u); [[ $SSH_UID != "0" ]] && SUDO_PREFIX="sudo" || SUDO_PREFIX=""; (ssh $${SSH_HOST} id traefik && echo "Traefik user exists.") || (ssh $${SSH_HOST} $${SUDO_PREFIX} adduser --disabled-login --disabled-password --gecos GECOS traefik && ssh $${SSH_HOST} $${SUDO_PREFIX} gpasswd -a traefik docker)

.PHONY: config-ask
config-ask:
	@${BIN}/reconfigure ${ENV_FILE} TRAEFIK_ROOT_DOMAIN=${ROOT_DOMAIN}
	@${BIN}/reconfigure_acme ${ENV_FILE}
	@${BIN}/reconfigure_dashboard ${ENV_FILE}
	@echo ""
	@${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_PLUGIN_MAXMIND_GEOIP) == "true" ]] && echo "yes" || echo "no") "Do you want to enable the MaxMind GeoIP client locator plugin" "?" && ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_PLUGIN_MAXMIND_GEOIP=true || ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_PLUGIN_MAXMIND_GEOIP=false || true
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_PLUGIN_MAXMIND_GEOIP) == "true" ]] && echo "You may create a free MaxMind account: https://www.maxmind.com/en/geolite2/signup" && echo "Login to your MaxMind account and create a License Key." && echo "" && ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_GEOIPUPDATE_ACCOUNT_ID "Enter your MaxMind account ID" && ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_GEOIPUPDATE_LICENSE_KEY "Enter your MaxMind license key" && ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_GEOIPUPDATE_EDITION_IDS "Enter the GeoIP database IDs you wish to install" "GeoLite2-ASN GeoLite2-City GeoLite2-Country" || true
	@echo ""
	@${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENABLED) == "true" ]] && echo "yes" || echo "no") "Do you want to run Traefik exclusively inside a VPN (wireguard server mode)" "?" && make --no-print-directory config-wireguard || ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_ENABLED=false || true
	@echo ""
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENABLED) != "true" ]] && ${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_CLIENT_ENABLED) == "true" ]] && echo "yes" || echo "no") "Do you want to run Traefik as a reverse proxy for an external VPN (wireguard client mode)" "?" && make --no-print-directory config-wireguard-client || ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_CLIENT_ENABLED=false || true
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENABLED) != "true" ]] && [[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_CLIENT_ENABLED) != "true" ]] && ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_NETWORK_MODE=host TRAEFIK_DASHBOARD_ENTRYPOINT_HOST=127.0.0.1 || true
	@TRAEFIK_UID=$$(ssh $$(docker context inspect | jq -r ".[0].Endpoints.docker.Host") id -u traefik) && ${BIN}/dotenv -f ${ENV_FILE} set TRAEFIK_UID=$${TRAEFIK_UID} && echo "Set TRAEFIK_UID=$${TRAEFIK_UID}"
	@TRAEFIK_GID=$$(ssh $$(docker context inspect | jq -r ".[0].Endpoints.docker.Host") id -g traefik) && ${BIN}/dotenv -f ${ENV_FILE} set TRAEFIK_GID=$${TRAEFIK_GID} && echo "Set TRAEFIK_GID=$${TRAEFIK_GID}"
	@TRAEFIK_DOCKER_GID=$$(ssh $$(docker context inspect | jq -r ".[0].Endpoints.docker.Host") getent group docker | cut -d: -f3) && ${BIN}/dotenv -f ${ENV_FILE} set TRAEFIK_DOCKER_GID=$${TRAEFIK_DOCKER_GID} && echo "Set TRAEFIK_DOCKER_GID=$${TRAEFIK_DOCKER_GID}"

.PHONY: config-wireguard
config-wireguard:
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_HOST "Enter the public Traefik VPN hostname" vpn.${ROOT_DOMAIN}
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
	@export DOCKER_CONTEXT=${DOCKER_CONTEXT} ENV_FILE=${ENV_FILE} CONTEXT_INSTANCE=${CONTEXT_INSTANCE}; DASHBOARD_PORT=$$(comm -23 <(seq 49152 65535) <(ss -tan | awk '{print $4}' | cut -d':' -f2 | grep "[0-9]\{1,5\}" | sort | uniq) | shuf | head -n 1) && curl localhost:$${DASHBOARD_PORT} 2>&1 >/dev/null && ${BIN}/open /dashboard/#/http/routers 127.0.0.1:$${DASHBOARD_PORT} http || (set -x; ssh -N -L $${DASHBOARD_PORT}:127.0.0.1:8080 $$(docker context inspect | jq -r '.[0]["Endpoints"]["docker"]["Host"]' | sed 's|^ssh://||') &  echo "Starting SSH Tunnel ..." && sleep 5 && ${BIN}/open /dashboard/#/http/routers 127.0.0.1:$${DASHBOARD_PORT} http)

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
	docker compose --env-file=${ENV_FILE} exec -it traefik /bin/sh

.PHONY: shell-root
shell-root:
	docker compose --env-file=${ENV_FILE} exec --user root -it traefik /bin/sh


.PHONY: shell-wireguard
shell-wireguard:
	docker compose --env-file=${ENV_FILE} exec -it wireguard /bin/sh

.PHONY: shell-wireguard-client
shell-wireguard-client:
	docker compose --env-file=${ENV_FILE} exec -it wireguard-client /bin/sh

.PHONY: compose-profiles
compose-profiles:
	@${BIN}/reconfigure_compose_profiles ${ENV_FILE} TRAEFIK_PLUGIN_MAXMIND_GEOIP=geoip_update TRAEFIK_VPN_ENABLED=wireguard TRAEFIK_VPN_CLIENT_ENABLED=wireguard-client

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
