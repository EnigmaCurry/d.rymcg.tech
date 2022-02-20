ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_TRAEFIK_HOST "Enter the wireguard domain name" vpn.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_PEERS "Enter the wireguard peer names (comma separated)"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_SUBNET "Enter the wireguard internal subnet" 10.13.16.0/24
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_HOST_PORT "Enter the wireguard host port" 51820
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_NETWORKS "Enter the docker networks to allow (comma separated)" traefik-wireguard
	@${BIN}/reconfigure ${ENV_FILE} WIREGUARD_ALLOWEDIPS=$$(${BIN}/subnet_ip $$(${BIN}/dotenv get WIREGUARD_SUBNET))/32,$$(${BIN}/docker_subnets $$(${BIN}/dotenv get WIREGUARD_NETWORKS))

.PHONY: get-configs # Download the wireguard client config files from the server
get-configs:
	@mkdir -p wireguard_config
	@${BIN}/split_echo $$(${BIN}/dotenv get WIREGUARD_PEERS) "," | xargs -t -iXX docker-compose cp wireguard:/config/peer_XX wireguard_config
	@echo "Wireguard peer configs downloaded to ./wireguard_config"

.PHONY: client-install # Install the local wireguard config
client-install:
	@CONF=/etc/wireguard/$$(${BIN}/dotenv get WIREGUARD_TRAEFIK_HOST | sha256sum | head -c 8).conf && TMP_FILE=$$(mktemp) && read -p "Enter the name of the local peer client (eg. $${HOSTNAME}): " PEER && docker-compose cp wireguard:/config/peer_$${PEER}/peer_$${PEER}.conf $${TMP_FILE} && sudo cp $${TMP_FILE} $${CONF} && echo "Copied client config \"$${PEER}\": $${CONF}"
	@echo You can start the client with \`make client-start\`

.PHONY: client-start  # Start the local wireguard client (Run client-install first)
client-start: client-up

.PHONY: client-up
client-up:
	sudo wg-quick up $$(${BIN}/dotenv get WIREGUARD_TRAEFIK_HOST  | sha256sum | head -c 8)

.PHONY: client-stop  # Stop the local wireguard client
client-stop: client-down

.PHONY: client-down
client-down:
	sudo wg-quick down $$(${BIN}/dotenv get WIREGUARD_TRAEFIK_HOST  | sha256sum | head -c 8)

.PHONY: client-remove # Remove the local wireguard client
client-remove: client-down
	sudo rm /etc/wireguard/$$(${BIN}/dotenv get WIREGUARD_TRAEFIK_HOST  | sha256sum | head -c 8).conf

.PHONY: client-status # Show client status
client-status:
	sudo wg show $$(${BIN}/dotenv get WIREGUARD_TRAEFIK_HOST  | sha256sum | head -c 8)

.PHONY: client-expose-port # Expose TCP port to the traefik-wireguard network
client-expose-port:
	@${BIN}/confirm yes "WARNING: this will expose a private TCP port to Traefik"
	@PRIVATE_IP=$$(ip addr show dev $$(${BIN}/dotenv get WIREGUARD_TRAEFIK_HOST  | sha256sum | head -c 8) | grep inet | grep -oP ".*inet \K[^/ ]*") WIREGUARD_PUBLIC_IP=$$(docker inspect wireguard-wireguard-1 | jq -r '.[0]["NetworkSettings"]["Networks"]["traefik-wireguard"]["IPAddress"]') && read -e -p "Enter the private wireguard IP address: " -i $${PRIVATE_IP} PRIVATE_IP && read -e -p "Enter the TCP port number to expose: " TCP_PORT && ${BIN}/confirm yes "This will expose $${WIREGUARD_PUBLIC_IP}:$${TCP_PORT} -> $${PRIVATE_IP}:$${TCP_PORT}" && echo "" && ${BIN}/iptables_dnat wireguard-wireguard-1 $${WIREGUARD_PUBLIC_IP} $${TCP_PORT} $${PRIVATE_IP} $${TCP_PORT}
	@echo ""
	@echo "Done."
	@echo "Note: This rule will only persist for the current wireguard container lifetime."
	@echo "To remove all the rules, simply restart the wireguard container."
	@echo "You must now add a Traefik router to route traffic to this port."

.PHONY: ports # Show the current exposed ports
ports:
	docker-compose exec wireguard iptables -t nat -L PREROUTING

.PHONY: ports-flush # Flush (removes, closes) all client port mappings
ports-flush:
	@${BIN}/confirm yes "This will remove and close all the existing client port mappings"
	docker-compose exec wireguard iptables -t nat -F PREROUTING
	docker-compose exec wireguard iptables -t nat -L PREROUTING

.PHONY: shell
shell:
	@docker-compose exec wireguard /bin/bash
