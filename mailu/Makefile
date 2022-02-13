ROOT_DIR = ..
include ../_scripts/Makefile.projects-custom-build

.PHONY: build # Build
build:
# Non-Buildkit build because buildkit says it does not support build subdirs?!
	docker-compose build

.PHONY: config-ask
config-ask:
	@${BIN}/reconfigure CA_NAME=${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask MAILU_TRAEFIK_HOST "Enter the mailu server name" mail.${ROOT_DOMAIN}
	@${BIN}/reconfigure SECRET_KEY=$$(openssl rand -base64 16 | head -c 16)
	@${BIN}/reconfigure_ask SUBNET_PREFIX "Enter the first three octets for the new mail subnet" 192.168.203
	@${BIN}/reconfigure SUBNET=$$(${BIN}/dotenv get SUBNET_PREFIX).0/24
	@${BIN}/reconfigure_ask DOMAIN "Enter the main mail domain"
	@${BIN}/reconfigure_ask HOSTNAMES "Enter the names for the mail server (comma separated)" $$(${BIN}/dotenv get MAILU_TRAEFIK_HOST)
	@${BIN}/reconfigure_ask RELAYHOST "Enter your upstream SMTP (TLS) server and port number (use square brackets around hostname!)" [smtp.example.com]:465
	@${BIN}/reconfigure_ask RELAYUSER "Enter the upstream SMTP username"
	@${BIN}/reconfigure_ask RELAYPASSWORD "Enter the upstream SMTP password"

.PHONY: config # Configure .env file
config: config-ask cert fingerprint

.PHONY: cert # Create self-signed TLS certificate
cert:
	@${BIN}/confirm yes "certificate-ca will now create and sign a certificate for $$(${BIN}/dotenv get MAILU_TRAEFIK_HOST)"
#	Generate self-signed 100 year certificate:
	../_terminal/certificate-ca/cert-manager.sh ${ROOT_DOMAIN} create_ca
	../_terminal/certificate-ca/cert-manager.sh ${ROOT_DOMAIN} create $$(${BIN}/dotenv get MAILU_TRAEFIK_HOST)

.PHONY: fingerprint # View the TLS certificate fingerprint
fingerprint:
	@../_terminal/certificate-ca/cert-manager.sh ${ROOT_DOMAIN} fingerprint $$(${BIN}/dotenv get MAILU_TRAEFIK_HOST)
