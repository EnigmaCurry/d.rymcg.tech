ROOT_DIR = ../..
include ../../_scripts/Makefile.project-subproject

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask WHOAMI_TRAEFIK_HOST "Enter the whoami domain name" whoami-vpn.${ROOT_DOMAIN}

.PHONY: start # Start services
start:
	docker-compose -p whoami-vpn up -d 
