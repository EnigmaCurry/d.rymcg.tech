ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} WIREGUARD_INSTANCE=${instance}
	@echo
	@echo "## It will be useful for the wireguard container to have a static IP address,"
	@echo "## therefore you should create a unique subnet:"
	@${BIN}/reconfigure_subnet ${ENV_FILE} WIREGUARD_DOCKER_SUBNET "Enter a unique IPv4 subnet CIDR for the wireguard network" "$$(${BIN}/docker_subnets propose)"
	@${BIN}/reconfigure ${ENV_FILE} WIREGUARD_DOCKER_GATEWAY_ADDRESS=$$(${BIN}/ipcalc $$(${BIN}/dotenv -f ${ENV_FILE} get WIREGUARD_DOCKER_SUBNET) -j | jq -r ".MINADDR")
	@${BIN}/reconfigure ${ENV_FILE} WIREGUARD_DOCKER_WIREGUARD_ADDRESS=$$(${BIN}/ipcalc $$(${BIN}/dotenv -f ${ENV_FILE} get WIREGUARD_DOCKER_SUBNET) -j | jq -r ".MINADDR")
	@echo ""
	@echo "Enter the wireguard config values:"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_VPN_CLIENT_INTERFACE_PRIVATE_KEY "Enter the wireguard PrivateKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_VPN_CLIENT_INTERFACE_IPV4 "Enter the wireguard client IPv4 Interface Address"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_VPN_CLIENT_INTERFACE_IPV6 "Enter the wireguard client IPv6 Interface Address"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_VPN_CLIENT_INTERFACE_PEER_DNS "Enter the wireguard Interface DNS"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_VPN_CLIENT_PEER_PUBLIC_KEY "Enter the Peer PublicKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_VPN_CLIENT_PEER_ALLOWED_IPS "Enter the IP ranges you want to route over the VPN (comma separated; use '0.0.0.0/0,::0/0' to route all traffic on IPv4 and IPv6)"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_VPN_CLIENT_PEER_ENDPOINT "Enter the Peer Endpoint (host:port)"


.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=wireguard

.PHONY: check-mullvad
check-mullvad:
	docker compose --env-file=${ENV_FILE} exec -it wireguard /bin/sh -c "curl https://am.i.mullvad.net/json | jq"

.PHONY: override-hook
override-hook:
#### This sets the override template variables for docker-compose.instance.yaml:
#### The template dynamically renders to docker-compose.override_{DOCKER_CONTEXT}_{INSTANCE}.yaml
#### These settings are used to automatically generate the service container labels, and traefik config, inside the template.
#### The variable arguments have three forms: `=` `=:` `=@`
####   name=VARIABLE_NAME    # sets the template 'name' field to the value of VARIABLE_NAME found in the .env file
####                         # (this hardcodes the value into docker-compose.override.yaml)
####   name=:VARIABLE_NAME   # sets the template 'name' field to the literal string 'VARIABLE_NAME'
####                         # (this hardcodes the string into docker-compose.override.yaml)
####   name=@VARIABLE_NAME   # sets the template 'name' field to the literal string '${VARIABLE_NAME}'
####                         # (used for regular docker-compose expansion of env vars by name.)
	@${BIN}/docker_compose_override ${ENV_FILE} project=:qbitorrent instance=@WIREGUARD_INSTANCE docker_subnet=WIREGUARD_DOCKER_SUBNET docker_gateway_address=WIREGUARD_DOCKER_GATEWAY_ADDRESS docker_wireguard_address=WIREGUARD_DOCKER_WIREGUARD_ADDRESS


.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
