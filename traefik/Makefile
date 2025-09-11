ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-no-open

.PHONY: config-hook
config-hook: config-menu config-domain compose-profiles
	@echo ""
	@echo "Examine the configured environment file: ${ENV_FILE}"

config-hook-echo-postscript:
	@echo "Remember to re-install Traefik after all config changes."

.PHONY: config-menu
config-menu:
	@ENV_FILE=${ENV_FILE} DOCKER_CONTEXT=${DOCKER_CONTEXT} ROOT_DOMAIN=${ROOT_DOMAIN} ./setup.sh main_menu || true

.PHONY: config-domain
config-domain:
	@${BIN}/reconfigure ${ENV_FILE} TRAEFIK_ROOT_DOMAIN=${ROOT_DOMAIN}

.PHONY: config-acme
config-acme:
	@${BIN}/reconfigure_acme ${ENV_FILE} main || true

.PHONY: config-ca
config-ca:
	@${BIN}/reconfigure_ca ${ENV_FILE} main

.PHONY: open # Start SSH tunnel and open the Traefik Dashboard
open:
	@export ENV_FILE=${ENV_FILE} CONTEXT_INSTANCE=${CONTEXT_INSTANCE} PORT_FORWARD="$$(${BIN}/port_forward ${ENV_FILE} traefik 127.0.0.1:8080)"; if [[ ! "$${PORT_FORWARD}" =~ [0-9]+ ]]; then ${BIN}/fault "Could not get the SSH forwarded port"; else ${BIN}/open /dashboard/#/http/routers 127.0.0.1:$${PORT_FORWARD} http; fi;

.PHONY: cert
cert: certs

.PHONY: certs # Make TLS Certificates
certs:
	@${BIN}/reconfigure_certs ${ENV_FILE} main

.PHONY: config-inspect # Inspect the live configuration
config-inspect:
	@docker compose --env-file ${ENV_FILE} exec traefik sh -c "find /data/config -type f | xargs -iXX sh -c \"echo \#\! XX && cat XX && echo ''\""

.PHONY: shell # Enter a shell on the container
shell:
	@make --no-print-directory docker-compose-shell service=$${service:-$${SERVICE:-traefik}}

.PHONY: shell-root # Enter a shell on the container as root
shell-root:
	@make --no-print-directory docker-compose-shell service=$${service:-$${SERVICE:-traefik}} USERNAME=root

.PHONY: show-wireguard-peers # Show connection info for wireguard peers
show-wireguard-peers:
	docker compose --env-file=${ENV_FILE} exec -it wireguard /bin/sh -c 'ls /config/peer*/*.conf | xargs -iXX sh -c "echo && echo \#\#\ XX && cat XX"'

.PHONY: show-wireguard-peers-qr # Show QR codes for wireguard peers
show-wireguard-peers-qr:
	docker compose --env-file=${ENV_FILE} exec -it wireguard /bin/sh -c 'ls /config/peer*/*.conf | xargs -iXX sh -c "echo && echo \#\#\ XX && qrencode -t ansiutf8 < XX"'

.PHONY: compose-profiles
compose-profiles:
	@${BIN}/reconfigure_compose_profiles ${ENV_FILE} TRAEFIK_PLUGIN_MAXMIND_GEOIP=geoip_update TRAEFIK_VPN_ENABLED=wireguard TRAEFIK_VPN_CLIENT_ENABLED=wireguard-client TRAEFIK_ERROR_PAGES_ENABLED=error-pages TRAEFIK_ACME_SH_ENABLED=acme-sh

.PHONY: wireguard-reset
wireguard-reset:
	docker compose --env-file=${ENV_FILE} exec -it wireguard wg-quick down wg0

.PHONY: wireguard-client-reset
wireguard-client-reset:
	docker compose --env-file=${ENV_FILE} exec -it wireguard-client wg-quick down wg0

.PHONY: destroy-wireguard
destroy-wireguard:
	@docker compose --env-file ${ENV_FILE} --profile wireguard down -v

.PHONY: logs-traefik # Tail the Traefik logs
logs-traefik:
	@make --no-print-directory logs service=traefik

.PHONY: logs-access # Tail the access logs
logs-access:
	@docker compose --env-file ${ENV_FILE} --profile "$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES)" exec -it traefik sh -c 'tail -f /data/access.log | jq -c'

.PHONY: logs-access-out
logs-access-out:
	@docker compose --env-file ${ENV_FILE} --profile "$(${BIN}/dotenv -f ${ENV_FILE} get DOCKER_COMPOSE_PROFILES)" exec -it traefik sh -c 'tail -n 10000 /data/access.log | jq -c'

.PHONY: debug # Restart Traefik with debug logging for one time only
debug:
	@EXISTING_TRAEFIK_LOG_LEVEL=$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LOG_LEVEL) && ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_LOG_LEVEL=debug && make --no-print-directory install; STARTED=$$?; ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_LOG_LEVEL=$${EXISTING_TRAEFIK_LOG_LEVEL} && [[ "$$STARTED" == "0" ]] && make --no-print-directory logs-traefik

.PHONY: sentry
sentry:
	@${BIN}/reconfigure_header_authorization ${ENV_FILE}

.PHONY: sentry-callback
sentry-callback:
	@${BIN}/reconfigure_header_authorization ${ENV_FILE} list-callback-urls

.PHONY: route # Manage routes
route:
	@ENV_FILE=${ENV_FILE} ROOT_ENV=${ROOT_ENV} D_RYMCG_TECH_CONTEXT_ALIAS=$${D_RYMCG_TECH_CONTEXT_ALIAS} ARGS=$${ARGS} ${BIN}/route

.PHONY: lego-vars
lego-vars:
	./lego-vars/scrape_lego_vars.sh

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo

.PHONY: build-hook-pre
build-hook-pre:
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="build acme-sh-base"

.PHONY: acme-sh-cron-schedule
acme-sh-cron-schedule:
	@SCHEDULE="$$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_ACME_SH_CRON_SCHEDULE)"; make --no-print-directory docker-compose-shell SERVICE=acme-sh COMMAND="crontab -l"

.PHONY: acme-sh-register
acme-sh-register: build
	@make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="run --rm acme-sh register-acmedns"

.PHONY: acme-sh-cert
acme-sh-cert:
	BIN=${BIN} ENV_FILE=${ENV_FILE} ./acme-sh/script/create_cert.sh

.PHONY: acme-sh-destroy-certs
acme-sh-destroy-certs:
	@${BIN}/confirm no "Do you want to destroy all certificates" "?" && make --no-print-directory docker-compose-shell SERVICE=acme-sh COMMAND="find /acme.sh -mindepth 1 -maxdepth 1 -type d ! -name ca -exec rm -rf {} + && rm -rf /certs/*" && echo destroyed all certs
