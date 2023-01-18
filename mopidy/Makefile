ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} MOPIDY_TRAEFIK_HOST "Enter the mopidy domain name" mopidy${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} MOPIDY_IP_SOURCERANGE "Enter the IP sourcerange filters (CIDR ranges, comma separated)" 0.0.0.0/0
	@${BIN}/reconfigure ${ENV_FILE} MOPIDY_MPD_PASSWORD=$$(${BIN}/dotenv -f ${ENV_FILE} get MOPIDY_MPD_PASSWORD || openssl rand -hex 15)
	@echo
	@echo "Set the MPD_HOST variable in your client's .profile or .bashrc file:"
	@echo
	@echo "export MPD_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get MOPIDY_MPD_PASSWORD)@$$(${BIN}/dotenv -f ${ENV_FILE} get MOPIDY_TRAEFIK_HOST)"
	@echo
