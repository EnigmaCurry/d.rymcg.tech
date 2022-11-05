ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_TRAEFIK_VPN_ENTRYPOINT_HOST "Enter the private Traefik VPN IP address (on the server traefik-vpn network)" 172.15.0.1
	@echo "Copy the details of the peer config that you got from the server (Scan the QR code printed in the server's wireguard log) (should start with the line: [Interface]):"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_INTERFACE_ADDRESS "Enter the wireguard Interface Address"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_INTERFACE_PRIVATE_KEY "Enter the wireguard PrivateKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_INTERFACE_LISTEN_PORT "Enter the wireguard listen port" 51820

	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_INTERFACE_PEER_DNS "Enter the wireguard Interface DNS" 10.13.16.1
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_PEER_PUBLIC_KEY "Enter the Peer PublicKey"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_PEER_ENDPOINT "Enter the Peer Endpoint"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_CLIENT_PEER_ALLOWED_IPS "Enter the Peer AllowedIPs"
