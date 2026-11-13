ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} IMMICH_TRAEFIK_HOST "Enter the Immich domain name" immich${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} IMMICH_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} IMMICH
	@${BIN}/reconfigure_password ${ENV_FILE} IMMICH_DB_PASSWORD 45
	@echo
	@${BIN}/reconfigure_choose ${ENV_FILE} IMMICH_ML_HWACCEL_TYPE "Select the hardware acceleration to use for machine learning" "None" "CPU" "ArmNN" "Cuda" "ROCm" "OpenVINO" "OpenVINO-WSL"
	@echo
	@${BIN}/reconfigure_choose ${ENV_FILE} IMMICH_TRANSCODE_HWACCEL_TYPE "Select the hardware acceleration to use for transcoding" "None" "CPU" "NVENC" "QSV" "RKMPP" "VAAPI" "VAAPI-WSL"
	@echo
	@choices=('bind mount' 'Docker volume'); \
		[[ "$$(${BIN}/dotenv -f ${ENV_FILE} get IMMICH_USE_EXTERNAL_VOLUME)" == "false" ]] && default='Docker volume' || default='bind mount'; \
		answer=$$(eval "${BIN}/script-wizard choose 'Select whether you want Immich to upload images to a bind mount on the host or to a named Docker volume' $${choices[@]@Q} --default '$$default'"); \
		if [ "$$answer" = "bind mount" ]; then \
			${BIN}/reconfigure ${ENV_FILE} IMMICH_USE_EXTERNAL_VOLUME=true; \
			ALLOW_BLANK=0 ${BIN}/reconfigure_ask ${ENV_FILE} IMMICH_EXTERNAL_VOLUME "Enter the path on the host where you want Immich to upload new images (e.g., \"/mnt/photos\" or \"~/images\")." $$(${BIN}/dotenv -f "${ENV_FILE}" get "IMMICH_EXTERNAL_VOLUME"); \
		else \
			${BIN}/reconfigure ${ENV_FILE} IMMICH_USE_EXTERNAL_VOLUME=false; \
		fi
	@echo
	@${BIN}/reconfigure_choose ${ENV_FILE} IMMICH_DB_STORAGE_TYPE "Select \"HDD\" or \"SSD\", corresponding to the type of drive your database volume is installed on" "HDD" "SSD"
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:immich instance=@IMMICH_INSTANCE traefik_host=@IMMICH_TRAEFIK_HOST http_auth=IMMICH_HTTP_AUTH http_auth_var=@IMMICH_HTTP_AUTH ip_sourcerange=@IMMICH_IP_SOURCERANGE oauth2=IMMICH_OAUTH2 authorized_group=IMMICH_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=IMMICH_MTLS_AUTH mtls_authorized_certs=IMMICH_MTLS_AUTHORIZED_CERTS ml_hwaccel_type=IMMICH_ML_HWACCEL_TYPE use_external_volume=IMMICH_USE_EXTERNAL_VOLUME upload_location=IMMICH_EXTERNAL_VOLUME transcode_hwaccel_type=IMMICH_TRANSCODE_HWACCEL_TYPE db_storage_type=IMMICH_DB_STORAGE_TYPE homepage_labels_enable=IMMICH_HOMEPAGE_LABELS_ENABLE homepage_group_immich=IMMICH_HOMEPAGE_GROUP_IMMICH homepage_name_immich=IMMICH_HOMEPAGE_NAME_IMMICH homepage_icon_immich=IMMICH_HOMEPAGE_ICON_IMMICH homepage_description_immich=IMMICH_HOMEPAGE_DESCRIPTION_IMMICH homepage_show_stats_immich=IMMICH_HOMEPAGE_SHOW_STATS_IMMICH homepage_widget_enable=IMMICH_HOMEPAGE_WIDGET_ENABLE homepage_widget_api_key=IMMICH_HOMEPAGE_WIDGET_API_KEY traefik_entrypoint=IMMICH_TRAEFIK_ENTRYPOINT

.PHONY: shell
shell:
	@if [ -z "$(service)" ]; then \
		container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'immich' 'machine-learning' 'redis' 'database' --default 'immich'") && make --no-print-directory docker-compose-shell SERVICE=$${container}; \
	else \
		make --no-print-directory docker-compose-shell SERVICE=$$(service); \
	fi;

.PHONY: install-hook
install-hook:
	@echo

.PHONY: install-hook-pre
install-hook-pre:
	@echo
