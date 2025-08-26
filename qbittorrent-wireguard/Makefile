ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_TRAEFIK_HOST "Enter the qbittorrent domain name" qbittorrent${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} QBITTORRENT_INSTANCE=${instance}
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_PEER_PORT "Enter the public peer port qbittorrent should bind"
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_DOWNLOAD_VOLUME "Enter the absolute host path to store downloads" /tmp/downloads

	@echo ""
	@echo "Enter the wireguard config values:"
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_VPN_CLIENT_INTERFACE_PRIVATE_KEY "Enter the wireguard PrivateKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_VPN_CLIENT_INTERFACE_IPV4 "Enter the wireguard client IPv4 Interface Address"
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_VPN_CLIENT_INTERFACE_IPV6 "Enter the wireguard client IPv6 Interface Address"
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_VPN_CLIENT_INTERFACE_PEER_DNS "Enter the wireguard Interface DNS"
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_VPN_CLIENT_PEER_PUBLIC_KEY "Enter the Peer PublicKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_VPN_CLIENT_PEER_ENDPOINT "Enter the Peer Endpoint (host:port)"
	@${BIN}/reconfigure_ask ${ENV_FILE} QBITTORRENT_IP_SOURCERANGE "Enter the allowed client IP source range (eg. 192.168.1.1/24 or 0.0.0.0/0)"
	@${BIN}/reconfigure_auth ${ENV_FILE} QBITTORRENT

.PHONY: shell
shell:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'wireguard' 'qbittorrent' --default 'qbittorrent'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: check-vpn
check-vpn:
	docker compose --env-file=${ENV_FILE} exec -it qbittorrent /bin/sh -c "curl https://am.i.mullvad.net/json | jq"


### Why was destroy here?
# .PHONY: destroy # Deletes containers AND data volumes
# destroy: check-instance-project
# 	@${BIN}/confirm no "Do you want to destroy all $$(basename $${PWD}) services AND volumes for the given context/instance (${ENV_FILE})" "?" && (make --no-print-directory destroy-hook-pre-rule-exists 2>/dev/null && make --no-print-directory destroy-hook-pre  || true) && make --no-print-directory docker-compose-lifecycle-cmd  EXTRA_ARGS="down -v"  && (make --no-print-directory destroy-hook-post-rule-exists 2>/dev/null && make --no-print-directory destroy-hook-post  || true)

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:qbitorrent instance=@QBITTORRENT_INSTANCE traefik_host=@QBITTORRENT_TRAEFIK_HOST http_auth=QBITTORRENT_HTTP_AUTH http_auth_var=@QBITTORRENT_HTTP_AUTH ip_sourcerange=@QBITTORRENT_IP_SOURCERANGE oauth2=QBITTORRENT_OAUTH2 authorized_group=QBITTORRENT_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=QBITTORRENT_MTLS_AUTH mtls_authorized_certs=QBITTORRENT_MTLS_AUTHORIZED_CERTS


.PHONY: install-hook
install-hook:
	@echo
