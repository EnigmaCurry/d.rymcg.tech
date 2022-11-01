ROOT_DIR = ..
include ../_scripts/Makefile.projects-no-open

.PHONY: config # Configure Traefik .env file
config: config-ask
	@echo ""
	@echo 'Base configuration complete. Run `make certs` to configure certificate domains.'

.PHONY: config-ask
config-ask:
	@${BIN}/reconfigure_acme ${ENV_FILE}
	@${BIN}/reconfigure_dashboard ${ENV_FILE}

.PHONY: open # Start SSH tunnel and open the Traefik Dashboard
open:
	curl localhost:8080 2>&1 >/dev/null && ${BIN}/open /dashboard/#/http/routers 127.0.0.1:8080 http || (set -x; ssh -N -L 8080:127.0.0.1:8080 $$(docker context inspect | jq -r '.[0]["Endpoints"]["docker"]["Host"]' | sed 's|^ssh://||') &  echo "Starting SSH Tunnel ..." && sleep 5 && ${BIN}/open /dashboard/#/http/routers 127.0.0.1:8080 http)

.PHONY: close # Stop the dashboard SSH tunnel
close:
	pkill -f "^ssh -N -L 8080:localhost:8080 ssh.${ROOT_DOMAIN}"

.PHONY: cert
cert: certs

.PHONY: certs # Make TLS Certificates
certs:
	@${BIN}/reconfigure_certs ${ENV_FILE}
