ROOT_DIR = ..
include ../_scripts/Makefile.projects-no-open

.PHONY: config-hook # Configure .env file
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} BITWARDEN_PORT "Enter the localhost port to listen on" 8888


.PHONY: open # Start SSH tunnel and open bitwarden in the browser
open:
	@BITWARDEN_PORT=$$(${BIN}/dotenv -f ${ENV_FILE} get BITWARDEN_PORT); curl localhost:$${BITWARDEN_PORT} 2>&1 >/dev/null && ${BIN}/open / 127.0.0.1:$${BITWARDEN_PORT} http || (set -x; ssh -N -L $${BITWARDEN_PORT}:127.0.0.1:$${BITWARDEN_PORT} $$(docker context inspect | jq -r '.[0]["Endpoints"]["docker"]["Host"]' | sed 's|^ssh://||') &  echo "Starting SSH Tunnel ..." && sleep 5 && ${BIN}/open / 127.0.0.1:$${BITWARDEN_PORT} http)
