ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects-no-open

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} SYNCTHING_WEB_PORT=8384 SYNCTHING_LISTEN_PORT=22000 SYNCTHING_DISCOVERY_PORT=21027

.PHONY: open # Start SSH tunnel and open syncthing in the browser
open:
	@SYNCTHING_WEB_PORT=$$(${BIN}/dotenv -f ${ENV_FILE} get SYNCTHING_WEB_PORT); curl localhost:$${SYNCTHING_WEB_PORT} 2>&1 >/dev/null && ${BIN}/open / 127.0.0.1:$${SYNCTHING_WEB_PORT} http || (set -x; ssh -N -L $${SYNCTHING_WEB_PORT}:127.0.0.1:$${SYNCTHING_WEB_PORT} $$(docker context inspect | jq -r '.[0]["Endpoints"]["docker"]["Host"]' | sed 's|^ssh://||') &  echo "Starting SSH Tunnel ..." && sleep 5 && ${BIN}/open / 127.0.0.1:$${SYNCTHING_WEB_PORT} http)

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=syncthing
.PHONY: install-hook
install-hook:
	@echo
