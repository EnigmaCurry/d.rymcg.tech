ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

STEP=step-cli

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} NATS_TRAEFIK_HOST "Enter the NATS domain name" nats${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} NATS_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure ${ENV_FILE} NATS_CLUSTER_NAME=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} NATS_CLIENT_PORT "Enter the NATS client port to expose" 4222
	@${BIN}/confirm $$(test "$$(${BIN}/dotenv -f ${ENV_FILE} get NATS_JETSTREAM_ENABLE)" == "true" && echo "yes" || echo "no") "Do you want to enable JetStream (persistence, KV store, streams)" "?" && ${BIN}/reconfigure ${ENV_FILE} NATS_JETSTREAM_ENABLE=true || ${BIN}/reconfigure ${ENV_FILE} NATS_JETSTREAM_ENABLE=false
	@${BIN}/reconfigure_ask ${ENV_FILE} NATS_STEP_CA_URL "Enter the Step-CA URL" $$(cat $$(${STEP} path)/config/defaults.json | jq -r '."ca-url"')
	@echo
	@echo "Retrieving Step-CA fingerprint from $$(${BIN}/dotenv -f ${ENV_FILE} get NATS_STEP_CA_URL)/roots.pem ..."
	@${BIN}/reconfigure_ask ${ENV_FILE} NATS_STEP_CA_FINGERPRINT "VERIFY the Step-CA fingerprint" $$(${STEP} ca root | ${STEP} certificate fingerprint)
	@make --no-print-directory auth-users
	@EXISTING_TOKEN=$$(${BIN}/dotenv -f ${ENV_FILE} get NATS_STEP_CA_TOKEN); \
	if [[ -n "$${EXISTING_TOKEN}" ]]; then \
		echo "Existing NATS_STEP_CA_TOKEN found."; \
		if ! ${BIN}/confirm no "Do you want to request a new Step-CA token (requires Step-CA credentials)" "?"; then \
			echo "Keeping existing Step-CA token."; \
			exit 0; \
		fi; \
	fi; \
	${BIN}/reconfigure ${ENV_FILE} NATS_STEP_CA_TOKEN="" &>/dev/null; \
	echo "Retrieving one-time-use token from Step-CA server."; \
	echo "Get ready to enter your root Step-CA credentials!"; \
	echo; \
	${BIN}/reconfigure ${ENV_FILE} NATS_STEP_CA_TOKEN="$$(step-cli ca token $$(${BIN}/dotenv -f ${ENV_FILE} get NATS_TRAEFIK_HOST) --provisioner admin)"

.PHONY: auth-users
auth-users:
	@NATS_TRAEFIK_HOST=$$(${BIN}/dotenv -f ${ENV_FILE} get NATS_TRAEFIK_HOST); \
	CURRENT=$$(${BIN}/dotenv -f ${ENV_FILE} get NATS_AUTH_USERS); \
	if [[ -n "$${CURRENT}" ]]; then \
		IFS=';' read -ra ENTRIES <<< "$${CURRENT}"; \
	else \
		ENTRIES=(); \
	fi; \
	while true; do \
		echo; \
		echo "## NATS Authorization Users"; \
		if [[ $${#ENTRIES[@]} -gt 0 ]]; then \
			for i in "$${!ENTRIES[@]}"; do \
				IFS=':' read -r cn pub sub <<< "$${ENTRIES[$$i]}"; \
				echo "  $$((i+1)). $${cn}  publish=[$${pub:-DENY}] subscribe=[$${sub:-DENY}]"; \
			done; \
		else \
			echo "  No users configured (all access denied)."; \
		fi; \
		echo; \
		ACTION=$$(eval "${BIN}/script-wizard choose 'Manage auth users' 'done' 'add' 'edit' 'remove' --default 'done'") || break; \
		if [[ -z "$${ACTION}" || "$${ACTION}" == "done" ]]; then \
			break; \
		elif [[ "$${ACTION}" == "add" ]]; then \
			CN=$$(${BIN}/ask_echo "Enter client CN (domain)" "$${HOSTNAME}.clients.$${NATS_TRAEFIK_HOST}"); \
			MODE=$$(eval "${BIN}/script-wizard choose 'Permission mode' 'prefix' 'full' 'custom' --default 'prefix'"); \
			if [[ "$${MODE}" == "full" ]]; then \
				PUB=">"; \
				SUB=">"; \
			elif [[ "$${MODE}" == "prefix" ]]; then \
				PREFIX=$$(${BIN}/ask_echo "Enter subject prefix (e.g. hookshot.d2-admin)"); \
				KV_BUCKET=$$(echo "$${PREFIX}" | tr '.' '_')_history; \
				PUB="$${PREFIX}.>,\$$KV.$${KV_BUCKET}.>,\$$JS.API.*.KV_$${KV_BUCKET},\$$JS.API.*.*.KV_$${KV_BUCKET}"; \
				SUB="$${PREFIX}.>"; \
			elif [[ "$${MODE}" == "custom" ]]; then \
				PUB=$$(${BIN}/ask_echo_blank "Enter publish subjects (comma-separated, > for all, empty to deny)"); \
				SUB=$$(${BIN}/ask_echo_blank "Enter subscribe subjects (comma-separated, > for all, empty to deny)"); \
			fi; \
			ENTRIES+=("$${CN}:$${PUB}:$${SUB}"); \
			echo "Added: $${CN}"; \
		elif [[ "$${ACTION}" == "edit" ]]; then \
			if [[ $${#ENTRIES[@]} -eq 0 ]]; then \
				echo "No users to edit."; \
				continue; \
			fi; \
			CHOICES=(); \
			for e in "$${ENTRIES[@]}"; do \
				IFS=':' read -r cn _ _ <<< "$$e"; \
				CHOICES+=("$${cn}"); \
			done; \
			EDIT_CN=$$(eval "${BIN}/script-wizard choose 'Select user to edit' $${CHOICES[@]@Q}"); \
			for i in "$${!ENTRIES[@]}"; do \
				IFS=':' read -r cn old_pub old_sub <<< "$${ENTRIES[$$i]}"; \
				if [[ "$${cn}" == "$${EDIT_CN}" ]]; then \
					MODE=$$(eval "${BIN}/script-wizard choose 'Permission mode' 'prefix' 'full' 'custom' --default 'prefix'"); \
					if [[ "$${MODE}" == "full" ]]; then \
						PUB=">"; \
						SUB=">"; \
					elif [[ "$${MODE}" == "prefix" ]]; then \
						PREFIX=$$(${BIN}/ask_echo "Enter subject prefix (e.g. hookshot.d2-admin)"); \
						KV_BUCKET=$$(echo "$${PREFIX}" | tr '.' '_')_history; \
						PUB="$${PREFIX}.>,\$$KV.$${KV_BUCKET}.>,\$$JS.API.*.KV_$${KV_BUCKET},\$$JS.API.*.*.KV_$${KV_BUCKET}"; \
						SUB="$${PREFIX}.>"; \
					elif [[ "$${MODE}" == "custom" ]]; then \
						PUB=$$(${BIN}/ask_echo_blank "Enter publish subjects (comma-separated, > for all, empty to deny)" "$${old_pub}"); \
						SUB=$$(${BIN}/ask_echo_blank "Enter subscribe subjects (comma-separated, > for all, empty to deny)" "$${old_sub}"); \
					fi; \
					ENTRIES[$$i]="$${cn}:$${PUB}:$${SUB}"; \
					echo "Updated: $${cn}"; \
					break; \
				fi; \
			done; \
		elif [[ "$${ACTION}" == "remove" ]]; then \
			if [[ $${#ENTRIES[@]} -eq 0 ]]; then \
				echo "No users to remove."; \
				continue; \
			fi; \
			CHOICES=(); \
			for e in "$${ENTRIES[@]}"; do \
				IFS=':' read -r cn _ _ <<< "$$e"; \
				CHOICES+=("$${cn}"); \
			done; \
			RM_CN=$$(eval "${BIN}/script-wizard choose 'Select user to remove' $${CHOICES[@]@Q}"); \
			NEW_ENTRIES=(); \
			for e in "$${ENTRIES[@]}"; do \
				IFS=':' read -r cn _ _ <<< "$$e"; \
				if [[ "$${cn}" != "$${RM_CN}" ]]; then \
					NEW_ENTRIES+=("$$e"); \
				fi; \
			done; \
			ENTRIES=("$${NEW_ENTRIES[@]}"); \
			echo "Removed: $${RM_CN}"; \
		fi; \
	done; \
	RESULT=$$(IFS=';'; echo "$${ENTRIES[*]}"); \
	${BIN}/reconfigure ${ENV_FILE} NATS_AUTH_USERS="$${RESULT}"

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=nats

.PHONY: cert # Create a client TLS certificate
cert:
	@${STEP} ca roots > certs/root_ca.crt
	@CN=$$(${BIN}/ask_echo "Enter the client domain (CN) to be certified" ${HOSTNAME}.clients.$$(${BIN}/dotenv -f ${ENV_FILE} get NATS_TRAEFIK_HOST)); ${STEP} ca certificate "$${CN}" "certs/$${CN}.crt" "certs/$${CN}.key" --provisioner admin --not-after "$$(${BIN}/dotenv -f ${ENV_FILE} get NATS_CLIENT_CERT_EXPIRATION_HOURS)"h

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
