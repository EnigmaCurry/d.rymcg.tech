ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
#### This interactive configuration wizard creates the .env_{DOCKER_CONTEXT}_{INSTANCE} config file using .env-dist as the template:
#### reconfigure_ask asks the user a question to set the variable into the .env file, and with a provided default value.
#### reconfigure sets the value of a variable in the .env file without asking.
#### reconfigure_htpasswd will configure the HTTP Basic Authentication setting the var name and with a provided default value.
	@${BIN}/reconfigure_ask ${ENV_FILE} BITMAGNET_TRAEFIK_HOST "Enter the bitmagnet domain name" bitmagnet${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} BITMAGNET_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} BITMAGNET
	@echo 
	@${BIN}/reconfigure_password ${ENV_FILE} BITMAGNET_POSTGRES_PASSWORD
	@echo 
	@${BIN}/reconfigure_ask ${ENV_FILE} BITMAGNET_TMDB_API_KEY "Optional: Enter your TMDB API key" 
	@echo
	@echo "Enter the wireguard config values:"
	@${BIN}/reconfigure_ask ${ENV_FILE} BITMAGNET_VPN_CLIENT_INTERFACE_PRIVATE_KEY "Enter the wireguard PrivateKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} BITMAGNET_VPN_CLIENT_INTERFACE_IPV4 "Enter the wireguard client IPv4 Interface Address"
	@${BIN}/reconfigure_ask ${ENV_FILE} BITMAGNET_VPN_CLIENT_INTERFACE_IPV6 "Enter the wireguard client IPv6 Interface Address"
	@${BIN}/reconfigure_ask ${ENV_FILE} BITMAGNET_VPN_CLIENT_INTERFACE_PEER_DNS "Enter the wireguard Interface DNS"
	@${BIN}/reconfigure_ask ${ENV_FILE} BITMAGNET_VPN_CLIENT_PEER_PUBLIC_KEY "Enter the Peer PublicKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} BITMAGNET_VPN_CLIENT_PEER_ENDPOINT "Enter the Peer Endpoint (host:port)"
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} BITMAGNET_IP_SOURCERANGE "Enter the allowed client IP source range (eg. 192.168.1.1/24 or 0.0.0.0/0)"


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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:bitmagnet instance=@BITMAGNET_INSTANCE traefik_host=@BITMAGNET_TRAEFIK_HOST http_auth=BITMAGNET_HTTP_AUTH http_auth_var=@BITMAGNET_HTTP_AUTH ip_sourcerange=@BITMAGNET_IP_SOURCERANGE oauth2=BITMAGNET_OAUTH2 authorized_group=BITMAGNET_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=BITMAGNET_MTLS_AUTH mtls_authorized_certs=BITMAGNET_MTLS_AUTHORIZED_CERTS tmdb_api_key=BITMAGNET_TMDB_API_KEY

.PHONY: shell
shell:
	@container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'postgres' 'bitmagnet' 'wireguard' --default 'bitmagnet'") && make --no-print-directory docker-compose-shell SERVICE=$${container}