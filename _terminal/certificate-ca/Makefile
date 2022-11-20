ROOT_DIR = ../..

CA_NAME ?= local

.PHONY: help # Show this help screen
help:
	@echo "Certificate-CA Makefile help :"
	@grep -h '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/make \1 \t- \2/' | expand -t20

include ${ROOT_DIR}/_scripts/Makefile.globals

# Override the default 'build' target, because this doesn't use docker-compose:
.PHONY: build # Build the container image
build:
	./cert-manager.sh ${CA_NAME} build

.PHONY: ca # Create the root Certificate Authority
ca:
	./cert-manager.sh ${CA_NAME} create_ca

.PHONY: cert # Create certificate
cert:
	@${BIN}/env_ask DOMAIN="Enter the domain name" CHANGE_UID="Enter the owner UID (eg. 1000)" CHANGE_GID="Enter the owner GID (eg. 1000)" ./cert-manager.sh ${CA_NAME} create

.PHONY: delete # Delete certificate
delete:
	@${BIN}/env_ask DOMAIN="Enter the domain name of the certificate to delete" ./cert-manager.sh  ${CA_NAME} delete

.PHONY: get # Get certificate
get:
	@${BIN}/env_ask DOMAIN="Enter the domain name of the certificate to get" ./cert-manager.sh  ${CA_NAME} get

.PHONY: list # List certificate volumes
list:
	./cert-manager.sh  ${CA_NAME} list
