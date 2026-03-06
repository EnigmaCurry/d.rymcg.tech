ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} NATS_TRAEFIK_HOST "Enter the NATS monitoring domain" nats${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} NATS_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} NATS
	@${BIN}/reconfigure_ask ${ENV_FILE} NATS_CLUSTER_NAME "Enter the NATS cluster name" nats
	@${BIN}/reconfigure_password ${ENV_FILE} NATS_AUTHORIZATION_PASSWORD
	@${BIN}/reconfigure_ask ${ENV_FILE} NATS_CLIENT_PORT "Enter the NATS client port to expose" 4222

.PHONY: override-hook
override-hook:
	@${BIN}/docker_compose_override ${ENV_FILE} project=:nats instance=@NATS_INSTANCE traefik_host=@NATS_TRAEFIK_HOST http_auth=NATS_HTTP_AUTH http_auth_var=@NATS_HTTP_AUTH ip_sourcerange=@NATS_IP_SOURCERANGE oauth2=NATS_OAUTH2 authorized_group=NATS_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=NATS_MTLS_AUTH mtls_authorized_certs=NATS_MTLS_AUTHORIZED_CERTS homepage_labels_enable=NATS_HOMEPAGE_LABELS_ENABLE homepage_group_nats=NATS_HOMEPAGE_GROUP_NATS homepage_name_nats=NATS_HOMEPAGE_NAME_NATS homepage_icon_nats=NATS_HOMEPAGE_ICON_NATS homepage_description_nats=NATS_HOMEPAGE_DESCRIPTION_NATS homepage_show_stats_nats=NATS_HOMEPAGE_SHOW_STATS_NATS

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=nats

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
