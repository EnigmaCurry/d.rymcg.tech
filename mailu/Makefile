ROOT_DIR = ..
include ../_scripts/Makefile.projects-custom-build

.PHONY: build # Build
build:
# Non-Buildkit build because buildkit says it does not support build subdirs?!
	docker-compose build

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask MAILU_TRAEFIK_HOST "Enter the mailu server name" mail.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask WIREGUARD_PEERS "Enter wireguard peer names (comma separated)"
	@${BIN}/reconfigure_ask WIREGUARD_SUBNET "Enter a unique subnet for wireguard" 10.11.11.0/24
	@${BIN}/reconfigure SECRET_KEY=$$(openssl rand -base64 16 | head -c 16)
	@${BIN}/reconfigure_ask SUBNET_PREFIX "Enter the first three octets for the new mail subnet" 192.168.203
	@${BIN}/reconfigure SUBNET=$$(${BIN}/dotenv get SUBNET_PREFIX).0/24
	@${BIN}/reconfigure_ask DOMAIN "Enter the main mail domain"
	@${BIN}/reconfigure_ask HOSTNAMES "Enter the names for the mail server (comma separated)" $$(${BIN}/dotenv get MAILU_TRAEFIK_HOST)
	@${BIN}/reconfigure_ask RELAYHOST "Enter the dovecot SMTP (TLS) server and port number (use square brackets around hostname!)" [smtp.example.com]:465
	@${BIN}/reconfigure_ask RELAYUSER "Enter the SMTP username"
	@${BIN}/reconfigure_ask RELAYPASSWORD "Enter the SMTP password"

#	Generate self-signed 100 year certificate:
	../certificate-ca/cert-manager.sh build
	DOMAIN=$$(${BIN}/dotenv get MAILU_TRAEFIK_HOST)	../certificate-ca/cert-manager.sh create

