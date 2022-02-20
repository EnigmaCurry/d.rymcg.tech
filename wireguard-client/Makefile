ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure ${ENV_FILE} TRAEFIK_IP=$$(${BIN}/dotenv -f ../traefik-private/.env get TRAEFIK_WIREGUARD_SUBNET_IP)
	@echo "Copy the connection details from the config you got from the server:"
	@${BIN}/reconfigure_ask ${ENV_FILE} ADDRESS "Enter the wireguard Address"
	@${BIN}/reconfigure_ask ${ENV_FILE} PRIVATEKEY "Enter the wireguard PrivateKey"
	@${BIN}/reconfigure_ask ${ENV_FILE} DNS "Enter the wireguard DNS"
	@${BIN}/reconfigure_ask ${ENV_FILE} PUBLICKEY "Enter the wireguard PublicKey"
	@${BIN}/reconfigure_ask ${ENV_FILE} ENDPOINT "Enter the wireguard Endpoint"
	@${BIN}/reconfigure_ask ${ENV_FILE} ALLOWEDIPS "Enter the wireguard AllowedIPs"
