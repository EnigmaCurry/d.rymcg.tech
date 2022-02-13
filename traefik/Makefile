ROOT_DIR = ..
include ../_scripts/Makefile.projects-no-open

.PHONY: config # Configure Traefik .env file
config:
	@echo "Let's Encrypt will helpfully email you when your certificates are about to expire."
	@${BIN}/reconfigure_ask ACME_CA_EMAIL "Enter your email address for Let's Encrypt (blank to skip)"
	@echo ""
	@echo "It's important to protect the dashboard and so a username/password is required."
	@${BIN}/reconfigure_htpasswd TRAEFIK_DASHBOARD_AUTH
	@${BIN}/reconfigure TRAEFIK_PROXY_SUBNET_IP="$$(${BIN}/subnet_prefix $$(${BIN}/docker_subnets traefik-proxy))".3
	@${BIN}/reconfigure TRAEFIK_WIREGUARD_SUBNET_IP="$$(${BIN}/subnet_prefix $$(${BIN}/docker_subnets traefik-wireguard))".3
	@${BIN}/reconfigure TRAEFIK_WIREGUARD_SUBNET="$$(${BIN}/docker_subnets traefik-wireguard)"


.PHONY: open # Start SSH tunnel and open the Traefik Dashboard
open:
	@curl localhost:8080 2>&1 >/dev/null && ${BIN}/open /dashboard/#/http/routers 127.0.0.1:8080 http || (ssh -N -L 8080:localhost:8080 ssh.${ROOT_DOMAIN} &  echo "Starting SSH Tunnel ..." && sleep 5 && ${BIN}/open /dashboard/#/http/routers 127.0.0.1:8080 http)

.PHONY: close # Stop the dashboard SSH tunnel
close:
	pkill -f "^ssh -N -L 8080:localhost:8080 ssh.${ROOT_DOMAIN}"

