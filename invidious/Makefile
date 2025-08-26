ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} INVIDIOUS_TRAEFIK_HOST "Enter the invidious domain name" yt${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_password ${ENV_FILE} INVIDIOUS_POSTGRES_PASSWORD
	@${BIN}/reconfigure ${ENV_FILE} INVIDIOUS_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} INVIDIOUS
	@echo ""
	@${BIN}/reconfigure_password ${ENV_FILE} INVIDIOUS_HMAC_KEY 32
	@echo
	@echo "In the ongoing battle to bypass Google's attempt to block non-Google services from scraping public Youtube videos and information, the current method for Invidious to work is to pass a Proof of Origin Token to Google (if your public IP is blocked by Google). To generate po_token and visitor_data identities for passing all verification checks on the YouTube side, run \`docker run quay.io/invidious/youtube-trusted-session-generator\` on the same public IP address as the one blocked by YouTube, and enter the \`visitor_data\` and \`po_token\` values here. The \`po_token\` and \`visitor_data\` tokens will make your entire Invidious session more easily traceable by YouTube because it is tied to a unique identifier - more info here: https://docs.invidious.io/installation/#docker-compose-method-production"
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} INVIDIOUS_VISITOR_DATA "Enter the visitor_data token" yt${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} INVIDIOUS_PO_TOKEN "Enter the po_token token" yt${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@echo

.PHONY: override-hook
override-hook:
#### This sets the override template variables for docker-compose.instance.yaml:
#### The template dynamically renders to docker-compose.override_{DOCKER_CONTEXT}_{INSTANCE}.yaml
#### These settings are used to automatically generate the service container labels, and traefik config, inside the template.
#### The variable arguments have three forms: `=` `=:` `=@`
####   name=VARIABLE_NAME    # sets the template 'name' field to the value of VARIABLE_NAME found in the .env file
####                         # (this hardcodes the value into docker-compose.override.yaml)
####   name=:VARIABLE_NAME   # sets the template 'name' field to the literal string 'VARIABLE_NAME'
####                         # (this hardcodes the string into docker-compose.override.yaml)
####   name=@VARIABLE_NAME   # sets the template 'name' field to the literal string '${VARIABLE_NAME}'
####                         # (used for regular docker-compose expansion of env vars by name.)
	@${BIN}/docker_compose_override ${ENV_FILE} project=:invidious instance=@INVIDIOUS_INSTANCE traefik_host=@INVIDIOUS_TRAEFIK_HOST http_auth=INVIDIOUS_HTTP_AUTH http_auth_var=@INVIDIOUS_HTTP_AUTH ip_sourcerange=@INVIDIOUS_IP_SOURCERANGE oauth2=INVIDIOUS_OAUTH2 authorized_group=INVIDIOUS_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=INVIDIOUS_MTLS_AUTH mtls_authorized_certs=INVIDIOUS_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'postgres' 'invidious' 'inv_sig_helper'--default 'invidious'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
