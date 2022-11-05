ROOT_DIR = ..
include ../_scripts/Makefile.projects-no-open

.PHONY: network # Create Docker networks
network:
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENTRYPOINT_ENABLED) == "true" ]] && (docker network inspect traefik-vpn >/dev/null 2>&1 || (echo "" && echo "Creating traefik-vpn network ..." && docker network create traefik-vpn --subnet "$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_SUBNET)" || true)) && echo "" && echo "Traefik VPN network:" && docker network ls | grep traefik-vpn && docker network inspect traefik-vpn | grep Subnet && echo "Traefik VPN entrypoint: $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENTRYPOINT_HOST):$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENTRYPOINT_PORT)" || true

.PHONY: config # Configure Traefik .env file
config: config-ask network
	@echo ""
	@echo 'Base configuration complete. Run `make certs` to configure certificate domains.'

.PHONY: config-ask
config-ask:
	@${BIN}/reconfigure_acme ${ENV_FILE}
	@${BIN}/reconfigure_dashboard ${ENV_FILE}
	@echo ""
	@${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_PLUGIN_MAXMIND_GEOIP) == "true" ]] && echo "yes" || echo "no") "Do you want to enable the MaxMind GeoIP client locator plugin" "?" && ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_PLUGIN_MAXMIND_GEOIP=true || ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_PLUGIN_MAXMIND_GEOIP=false || true
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_PLUGIN_MAXMIND_GEOIP) == "true" ]] && echo "You may create a free MaxMind account: https://www.maxmind.com/en/geolite2/signup" && echo "Login to your MaxMind account and create a License Key." && echo "" && ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_GEOIPUPDATE_ACCOUNT_ID "Enter your MaxMind account ID" && ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_GEOIPUPDATE_LICENSE_KEY "Enter your MaxMind license key" && ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_GEOIPUPDATE_EDITION_IDS "Enter the GeoIP database IDs you wish to install" "GeoLite2-ASN GeoLite2-City GeoLite2-Country" || true
	@echo ""
	@${BIN}/confirm $$([[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENTRYPOINT_ENABLED) == "true" ]] && echo "yes" || echo "no") "Do you want to enable the Traefik VPN entrypoint (not necessary for the client)" "?" && ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_ENTRYPOINT_ENABLED=true || ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_ENTRYPOINT_ENABLED=false || true
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENTRYPOINT_ENABLED) == "true" ]] && ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_SUBNET "Enter the docker network subnet for the Traefik VPN" 172.15.0.0/16 || true
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENTRYPOINT_ENABLED) == "true" ]] && ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_ENTRYPOINT_HOST "Enter the Traefik container IP address for the traefik-vpn network" 172.15.0.3  || true
	@[[ $$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENTRYPOINT_ENABLED) == "true" ]] && ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_ENTRYPOINT_PORT "Enter the Traefik VPN entrypoint TCP port number" 443 || true

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
