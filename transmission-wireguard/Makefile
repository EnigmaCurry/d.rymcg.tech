ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} TRANSMISSION_TRAEFIK_HOST "Enter the transmission domain name" transmission${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} TRANSMISSION_INSTANCE=${instance}
	@${BIN}/reconfigure_ask ${ENV_FILE} TRANSMISSION_DOWNLOAD_VOLUME "Enter the absolute host path to store downloads" /tmp/downloads
	@${BIN}/reconfigure_ask ${ENV_FILE} TRANSMISSION_WATCH_VOLUME "Enter the absolute host path to store watched torrents" /tmp/torrents

	@echo ""
	@echo "Enter the wireguard config values:"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRANSMISSION_VPN_CLIENT_INTERFACE_PRIVATE_KEY "Enter the wireguard PrivateKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRANSMISSION_VPN_CLIENT_INTERFACE_ADDRESS "Enter the wireguard client Interface Addresses (comma separated)"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRANSMISSION_VPN_CLIENT_INTERFACE_PEER_DNS "Enter the wireguard Interface DNS"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRANSMISSION_VPN_CLIENT_PEER_PUBLIC_KEY "Enter the Peer PublicKey (ends with =)"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRANSMISSION_VPN_CLIENT_PEER_ALLOWED_IPS "Enter the Peer AllowedIPs"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRANSMISSION_VPN_CLIENT_PEER_ENDPOINT "Enter the Peer Endpoint (host:port)"
	@${BIN}/reconfigure_ask ${ENV_FILE} TRANSMISSION_IP_SOURCE_RANGE "Enter the allowed client IP source range (eg. 192.168.1.1/24 or 0.0.0.0/0)"
	@${BIN}/reconfigure_htpasswd ${ENV_FILE} TRANSMISSION_HTTP_AUTH

.PHONY: shell
shell:
	docker compose --env-file=${ENV_FILE} exec -it transmission /bin/bash

.PHONY: check-vpn
check-vpn:
	docker compose --env-file=${ENV_FILE} exec -it transmission /bin/sh -c "curl https://am.i.mullvad.net/json | jq"


.PHONY: destroy # Deletes containers AND data volumes
destroy: check-instance-project
	@${BIN}/confirm no "Do you want to destroy all $$(basename $${PWD}) services AND volumes for the given context/instance (${ENV_FILE})" "?" && (make --no-print-directory destroy-hook-pre-rule-exists 2>/dev/null && make --no-print-directory destroy-hook-pre  || true) && make --no-print-directory docker-compose-lifecycle-cmd  EXTRA_ARGS="down -v"  && (make --no-print-directory destroy-hook-post-rule-exists 2>/dev/null && make --no-print-directory destroy-hook-post  || true)
