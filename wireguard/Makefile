ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask WIREGUARD_TRAEFIK_HOST "Enter the wireguard domain name" wireguard.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask WIREGUARD_PEERS "Enter the wireguard peer names (comma separated)" client1,client2
	@${BIN}/reconfigure_ask WIREGUARD_SUBNET "Enter the wireguard internal subnet" 10.13.16.0
	@${BIN}/reconfigure_ask WIREGUARD_HOST_PORT "Enter the wireguard host port" 51820
