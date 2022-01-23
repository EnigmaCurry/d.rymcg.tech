ROOT_DIR = ..

.PHONY: help # Show this help screen
help:
	@echo "Certificate-CA Makefile help :"
	@grep -h '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/make \1 \t- \2/' | expand -t20

include ../_scripts/Makefile.globals

.PHONY: config # Configure whoami .env file
config:
	@${BIN}/reconfigure_ask GITEA_TRAEFIK_HOST "Enter the gitea domain name (eg. git.example.com)"

# Override the default 'build' target, because this doesn't use docker-compose:
.PHONY: build # Build the container image
build:
	./cert-manager.sh build

.PHONY: ca # Create the root Certificate Authority
ca:
	./cert-manager.sh create_ca

.PHONY: cert # Create certificate
cert:
	@${BIN}/env_ask DOMAIN="Enter the domain name" CHANGE_UID="Enter the owner UID (eg. 1000)" CHANGE_GID="Enter the owner GID (eg. 1000)" ./cert-manager.sh create

.PHONY: delete # Delete certificate
delete:
	@${BIN}/env_ask DOMAIN="Enter the domain name of the certificate to delete" ./cert-manager.sh delete

.PHONY: get # Get certificate
get:
	@${BIN}/env_ask DOMAIN="Enter the domain name of the certificate to get" ./cert-manager.sh get

.PHONY: list # List certificate volumes
list:
	./cert-manager.sh list
