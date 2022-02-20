ROOT_DIR = ..
include ../_scripts/Makefile.projects-custom-build

.PHONY: build # Build
build:
# Non-Buildkit build because buildkit says it does not support build subdirs?!
	docker-compose --env-file=${ENV_FILE} build

.PHONY: config-ask
config-ask:
	@${BIN}/reconfigure ${ENV_FILE} CA_NAME=${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} MAILU_TRAEFIK_HOST "Enter the mailu server name" mail.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} SECRET_KEY=$$(openssl rand -base64 16 | head -c 16)

	@${BIN}/reconfigure_ask ${ENV_FILE} SUBNET "Enter the subnet for the private mail network" 192.168.203.0/24
	@${BIN}/reconfigure ${ENV_FILE} SUBNET_PREFIX=$$(${BIN}/subnet_prefix $$(${BIN}/dotenv get SUBNET))

	@${BIN}/reconfigure ${ENV_FILE} TRAEFIK_MAIL_SUBNET=$$(${BIN}/dotenv -f ../traefik/.env get TRAEFIK_MAIL_SUBNET)
	@${BIN}/reconfigure ${ENV_FILE} TRAEFIK_MAIL_SUBNET_PREFIX=$$(${BIN}/subnet_prefix $$(${BIN}/dotenv get TRAEFIK_MAIL_SUBNET))

	@${BIN}/reconfigure_ask ${ENV_FILE} DOMAIN "Enter the main mail domain"
	@${BIN}/reconfigure ${ENV_FILE} HOSTNAMES=$$(${BIN}/dotenv get MAILU_TRAEFIK_HOST)
	@${BIN}/reconfigure_ask ${ENV_FILE} RELAYHOST "Enter your upstream SMTP (TLS) server and port number (use square brackets around hostname!)" [smtp.example.com]:465
	@${BIN}/reconfigure_ask ${ENV_FILE} RELAYUSER "Enter the upstream SMTP username"
	@${BIN}/reconfigure_ask ${ENV_FILE} RELAYPASSWORD "Enter the upstream SMTP password"
	@${BIN}/reconfigure_ask ${ENV_FILE} POSTMASTER "Enter the admin account name" admin

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

.PHONY: admin # Create admin account and/or reset password
admin:
	@${BIN}/confirm yes "This will create the admin POSTMASTER account, and/or reset the password for it"
	@PASSWORD=$$(openssl rand -base64 45) DOMAIN=$$(${BIN}/dotenv get DOMAIN) POSTMASTER=$$(${BIN}/dotenv get POSTMASTER) && docker-compose --env-file=${ENV_FILE} exec admin flask mailu admin --mode update $${POSTMASTER} $${DOMAIN} "$${PASSWORD}" && echo "Username: $${POSTMASTER}@$${DOMAIN}" && echo "Password: $${PASSWORD}"
