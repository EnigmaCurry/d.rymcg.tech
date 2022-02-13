ROOT_DIR = ..
include ../_scripts/Makefile.projects-no-open

.PHONY: network # Create Docker networks
network:
	docker network inspect traefik-proxy >/dev/null 2>&1 || docker network create traefik-proxy --subnet $$(${BIN}/dotenv get TRAEFIK_PROXY_SUBNET)
	docker network inspect traefik-wireguard  >/dev/null 2>&1 || docker network create traefik-wireguard --subnet $$(${BIN}/dotenv get TRAEFIK_WIREGUARD_SUBNET)

.PHONY: config # Configure Traefik .env file
config: config-ask network

.PHONY: config-ask
config-ask:
	@echo "Let's Encrypt will helpfully email you when your certificates are about to expire."
	@${BIN}/reconfigure_ask ACME_CA_EMAIL "Enter your email address for Let's Encrypt (blank to skip)"
	@echo ""
	@echo "It's important to protect the dashboard and so a username/password is required."
	@${BIN}/reconfigure_htpasswd TRAEFIK_DASHBOARD_AUTH
	@${BIN}/reconfigure_ask TRAEFIK_PROXY_SUBNET "Enter a subnet for the proxy network" 172.13.0.0/16
	@${BIN}/reconfigure TRAEFIK_PROXY_SUBNET_IP="$$(${BIN}/subnet_prefix $$(${BIN}/dotenv get TRAEFIK_PROXY_SUBNET))".3
	@${BIN}/reconfigure_ask TRAEFIK_WIREGUARD_SUBNET "Enter a subnet for the wireguard network" 172.15.0.0/16
	@${BIN}/reconfigure TRAEFIK_WIREGUARD_SUBNET_IP="$$(${BIN}/subnet_prefix $$(${BIN}/dotenv get TRAEFIK_WIREGUARD_SUBNET))".3

.PHONY: open # Start SSH tunnel and open the Traefik Dashboard
open:
	@TRAEFIK_IP=$$(${BIN}/dotenv get TRAEFIK_WIREGUARD_SUBNET_IP) && curl localhost:8080 2>&1 >/dev/null && ${BIN}/open /dashboard/#/http/routers 127.0.0.1:8080 http || (set -x; ssh -N -L 8080:$${TRAEFIK_IP}:8080 $$(docker context inspect | jq -r '.[0]["Endpoints"]["docker"]["Host"]' | sed 's|^ssh://||') &  echo "Starting SSH Tunnel ..." && sleep 5 && ${BIN}/open /dashboard/#/http/routers 127.0.0.1:8080 http)

.PHONY: close # Stop the dashboard SSH tunnel
close:
	pkill -f "^ssh -N -L 8080:localhost:8080 ssh.${ROOT_DOMAIN}"

