ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure ${ENV_FILE} WIREGUARD_GATEWAY_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_GATEWAY_LAN_INTERFACE "Enter the host LAN interface name (check \`ip addr\`)"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_GATEWAY_MAC_ADDRESS "Enter a random MAC address for the virtual NIC"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_GATEWAY_VPN_INTERFACE "Enter the VPN interface name (make sure it's unique on the host)"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_GATEWAY_PRIVATE_KEY "Enter the WireGuard client's PRIVATE key"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_GATEWAY_PEER_ENDPOINT "Enter the provided WireGuard peer endpoint (host:port)"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_GATEWAY_PEER_PUBLIC_KEY "Enter the peer's PUBLIC WireGuard key"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_GATEWAY_PEER_ALLOWED_IPS "Enter the allowed IPs to forward to the peer"
	@${BIN}/reconfigure_ask ${ENV_FILE} WIREGUARD_GATEWAY_VPN_IPV4 "Enter the VPN client's IPv4 address"
	@echo ""

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:wireguard_gateway instance=@WIREGUARD_GATEWAY_INSTANCE

.PHONY: shell # Enter container shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=wireguard_gateway

.PHONY: wg # Show WireGuard config
wg:
	@make --no-print-directory docker-compose-shell SERVICE=wireguard_gateway COMMAND="wg"
