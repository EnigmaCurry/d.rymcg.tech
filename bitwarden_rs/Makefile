ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask BITWARDEN_PORT "Enter the localhost port to listen on" 8888
