ROOT_DIR = ..
include ../_scripts/Makefile.projects-no-open

.PHONY: config # Configure Traefik .env file
config:
	@echo "Let's Encrypt will helpfully email you when your certificates are about to expire."
	@${BIN}/reconfigure_ask ACME_CA_EMAIL "Enter your email address for Let's Encrypt (blank to skip)" asdf@asdf.net

.PHONY: open # Start SSH tunnel and open the Traefik Dashboard
open:
	@curl localhost:8080 2>&1 >/dev/null && xdg-open http://localhost:8080/dashboard/#/http/routers || (ssh -N -L 8080:localhost:8080 ssh.${ROOT_DOMAIN} &  echo "Starting SSH Tunnel ..." && sleep 5 && xdg-open http://localhost:8080/dashboard/#/http/routers)

.PHONY: close # Stop the dashboard SSH tunnel 
close:
	pkill -f "^ssh -N -L 8080:localhost:8080 ssh.${ROOT_DOMAIN}"

