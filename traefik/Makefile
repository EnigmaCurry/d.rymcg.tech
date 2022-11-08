ROOT_DIR = ..
include ../_scripts/Makefile.projects-no-open

## TODO: delete this, because we don't need a specific vpn network anymore..
# .PHONY: network # Create Docker networks
# network:
# 	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENTRYPOINT_ENABLED) == "true" ]] && (docker network inspect traefik-vpn >/dev/null 2>&1 || (echo "" && echo "Creating traefik-vpn network ..." && docker network create traefik-vpn --subnet "$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_SUBNET)" || true)) && echo "" && echo "Traefik VPN network:" && docker network ls | grep traefik-vpn && docker network inspect traefik-vpn | grep Subnet && echo "Traefik VPN entrypoint: $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENTRYPOINT_HOST):$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENTRYPOINT_PORT)" || true

.PHONY: config # Configure Traefik .env file
config: config-ask compose-profiles
	@echo ""
	@echo 'Base configuration complete. Run `make certs` to configure certificate domains.'

.PHONY: config-ask
config-ask:
	@echo "Configuring $(realpath ${ENV_FILE})"
	@${BIN}/reconfigure_acme ${ENV_FILE}
	@${BIN}/reconfigure_dashboard ${ENV_FILE}
	@echo ""
	@${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_PLUGIN_MAXMIND_GEOIP) == "true" ]] && echo "yes" || echo "no") "Do you want to enable the MaxMind GeoIP client locator plugin" "?" && ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_PLUGIN_MAXMIND_GEOIP=true || ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_PLUGIN_MAXMIND_GEOIP=false || true
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_PLUGIN_MAXMIND_GEOIP) == "true" ]] && echo "You may create a free MaxMind account: https://www.maxmind.com/en/geolite2/signup" && echo "Login to your MaxMind account and create a License Key." && echo "" && ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_GEOIPUPDATE_ACCOUNT_ID "Enter your MaxMind account ID" && ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_GEOIPUPDATE_LICENSE_KEY "Enter your MaxMind license key" && ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_GEOIPUPDATE_EDITION_IDS "Enter the GeoIP database IDs you wish to install" "GeoLite2-ASN GeoLite2-City GeoLite2-Country" || true
	@echo ""
	@${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENABLED) == "true" ]] && echo "yes" || echo "no") "Do you want to run Traefik exclusively inside a VPN" "?" && make config-wireguard || ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_ENABLED=false || true
	@echo ""
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENABLED) != "true" ]] && ${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_CLIENT_ENABLED) == "true" ]] && echo "yes" || echo "no") "Do you want to run Traefik as a reverse proxy for an external VPN" "?" && make config-wireguard-client || ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_CLIENT_ENABLED=false || true
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENABLED) != "true" ]] && [[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_CLIENT_ENABLED) != "true" ]] && ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_NETWORK_MODE=host || true

.PHONY: config-wireguard
config-wireguard:
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_HOST "Enter the public Traefik VPN hostname" vpn.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_WEBSECURE_ENTRYPOINT_HOST "Enter the Traefik websecure entrypoint bind IP address" 10.13.16.1
	@${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_ENABLED=true TRAEFIK_NETWORK_MODE=service:wireguard

.PHONY: config-wireguard-client
config-wireguard-client:
	@echo ""
	@echo "Scan the QR code for the client credentials printed in the wireguard server's log. Copy the details from the decoded QR code (The first line should be: [Interface]):"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_INTERFACE_ADDRESS "Enter the wireguard Interface Address"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_INTERFACE_PRIVATE_KEY "Enter the wireguard PrivateKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_INTERFACE_LISTEN_PORT "Enter the wireguard listen port" 51820
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_INTERFACE_PEER_DNS "Enter the wireguard Interface DNS" 10.13.16.1
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_PEER_PUBLIC_KEY "Enter the Peer PublicKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_PEER_PRESHARED_KEY "Enter the Peer PresharedKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_PEER_ENDPOINT "Enter the Peer Endpoint (host:port)"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_PEER_ALLOWED_IPS "Enter the Peer AllowedIPs"
	@${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_CLIENT_ENABLED=true TRAEFIK_NETWORK_MODE=service:wireguard-client

.PHONY: open # Start SSH tunnel and open the Traefik Dashboard
open:
	curl localhost:8080 2>&1 >/dev/null && ${BIN}/open /dashboard/#/http/routers 127.0.0.1:8080 http || (set -x; ssh -N -L 8080:127.0.0.1:8080 $$(docker context inspect | jq -r '.[0]["Endpoints"]["docker"]["Host"]' | sed 's|^ssh://||') &  echo "Starting SSH Tunnel ..." && sleep 5 && ${BIN}/open /dashboard/#/http/routers 127.0.0.1:8080 http)

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
	@docker-compose --env-file ${ENV_FILE} exec traefik sh -c "find /data/config -type f | xargs -iXX sh -c \"echo \#\# XX\ && cat XX && echo ''\""

.PHONY: shell
shell:
	docker compose --env-file=${ENV_FILE} exec -it traefik /bin/sh

.PHONY: compose-profiles
compose-profiles:
	@${BIN}/reconfigure_compose_profiles ${ENV_FILE} TRAEFIK_PLUGIN_MAXMIND_GEOIP=geoip_update TRAEFIK_VPN_ENABLED=wireguard TRAEFIK_VPN_CLIENT_ENABLED=wireguard-client
