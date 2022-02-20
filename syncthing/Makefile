ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure ${ENV_FILE} LISTEN_PORT=22000 DISCOVERY_PORT=21027
