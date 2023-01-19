ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} MOPIDY_TRAEFIK_HOST "Enter the mopidy domain name" mopidy${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} MOPIDY_MPD_IP_SOURCERANGE "Enter the MPD client IP sourcerange filters (CIDR ranges, comma separated)" 0.0.0.0/0
	@${BIN}/reconfigure_ask ${ENV_FILE} MOPIDY_SNAPCAST_IP_SOURCERANGE "Enter the Snapcast client IP sourcerange filters (CIDR ranges, comma separated)" 0.0.0.0/0
	@MOPIDY_MPD_PASSWORD=$$(${BIN}/dotenv -f ${ENV_FILE} get MOPIDY_MPD_PASSWORD); test -n "$${MOPIDY_MPD_PASSWORD}" || MOPIDY_MPD_PASSWORD=$$(openssl rand -hex 15); ${BIN}/reconfigure ${ENV_FILE} MOPIDY_MPD_PASSWORD="$${MOPIDY_MPD_PASSWORD}"
	@echo
	@echo "Set the MPD_HOST variable in your client's .profile or .bashrc file:"
	@echo
	@echo "export MPD_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get MOPIDY_MPD_PASSWORD)@$$(${BIN}/dotenv -f ${ENV_FILE} get MOPIDY_TRAEFIK_HOST)"
	@echo

.PHONY: shell
shell:
	@docker-compose --env-file ${ENV_FILE} exec -it $${service:-mopidy} /bin/sh -c "/bin/bash || /bin/sh"

.PHONY: library
library:
	@docker-compose --env-file ${ENV_FILE} exec -it mopidy mopidy local scan

