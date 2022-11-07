ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config: config-ask network

.PHONY: network # Create Docker networks
network:
	@(docker network inspect traefik-vpn >/dev/null 2>&1 || (echo "" && echo "Creating traefik-vpn network ..." && docker network create traefik-vpn --subnet "$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_SUBNET)" || true)) && echo "" && echo "Traefik VPN network:" && docker network ls | grep traefik-vpn && docker network inspect traefik-vpn | grep Subnet || true
	@${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_SUBNET=$$(docker network inspect traefik-vpn | jq -r ".[0].IPAM.Config[0].Subnet")

.PHONY: config-ask
config-ask:
	@echo ""
	@echo "Scan the QR code for the client credentials printed in the wireguard server's log. Copy the details from the decoded QR code (The first line should be: [Interface]):"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_INTERFACE_ADDRESS "Enter the wireguard Interface Address"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_INTERFACE_PRIVATE_KEY "Enter the wireguard PrivateKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_INTERFACE_LISTEN_PORT "Enter the wireguard listen port" 51820
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_INTERFACE_PEER_DNS "Enter the wireguard Interface DNS" 10.13.16.1
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_PEER_PUBLIC_KEY "Enter the Peer PublicKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_PEER_PRESHARED_KEY "Enter the Peer PresharedKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_PEER_ENDPOINT "Enter the Peer Endpoint"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_PEER_ALLOWED_IPS "Enter the Peer AllowedIPs"

.PHONY: shell
shell:
	docker compose --env-file=${ENV_FILE} exec -it wireguard /bin/bash
