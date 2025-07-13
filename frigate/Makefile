ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
.ONESHELL:
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} FRIGATE_TRAEFIK_HOST "Enter the frigate domain name" frigate${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} FRIGATE_INSTANCE=$${instance:-default}
	@${BIN}/reconfigureigure_auth ${ENV_FILE} FRIGATE
	@echo
	@${BIN}/reconfigure_password ${ENV_FILE} FRIGATE_RTSP_PASSWORD 32
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} FRIGATE_SHM_SIZE "Enter the shared memory size (see here for an explanation and formula for calculating appropriate shared memory size: https://docs.frigate.video/frigate/installation/#calculating-required-shm-size"
	@echo
	@echo "For hardware acceleration, enter the path to the host hardware's \`/dev/\`"
	@echo '- E.g., Pass the USB Coral (needs to be modified for other versions)'
	@echo '  FRIGATE_VIDEO_HARDWARE_DEVICE=/dev/bus/usb'
	@echo '- E.g., Pass a PCIe Coral (follow driver instructions here: https://coral.ai/docs/m2/get-started/#2a-on-linux)'
	@echo '  FRIGATE_VIDEO_HARDWARE_DEVICE=/dev/apex_0'
	@echo '- E.g., For Raspberry Pi 4B'
	@echo '  FRIGATE_VIDEO_HARDWARE_DEVICE=/dev/video11'
	@echo '- E.g., For Intel hwaccel (needs to be updated for your hardware)'
	@echo '  FRIGATE_VIDEO_HARDWARE_DEVICE=/dev/dri/renderD129'
	@echo
	@ALLOW_BLANK=1 ${BIN}/reconfigure_ask ${ENV_FILE} FRIGATE_VIDEO_HARDWARE_DEVICE "For hardware acceleration, enter the path to the host hardware's device (\`/dev/XXX\`). Leave blank to not use hardware acceleration (also leave blank to use an AMD GPU, as its devices are mapped for you)."
	@echo
	@echo 'Enter the GPU type, or select "None" for no GPU.'
	@echo 'Frigate supports many different GPUs, each requiring custom configuration in'
	@echo "\`docker-compose.yaml\`, Frigate's \`config.conf\`, or both. See here for details:"
	@echo 'https://docs.frigate.video/configuration/hardware_acceleration/'
	@echo
	@echo 'Currently, the d.rymcg.tech installation process only supports Nvidia. If your'
	@echo "GPU only requires custom configuration in Frigate's \`config.conf\`, you can enter"
	@echo '"None" here and then customize `config.conf` from within Frigate''s UI. Or feel'
	@echo 'free to submit a feature request for us to add support for your GPU:'
	@echo 'https://github.com/EnigmaCurry/d.rymcg.tech/issues'
	@echo
	@echo '# Possible values are "Nvidia", "AMD", or "None".'
	@${BIN}/reconfigure_choose ${ENV_FILE} FRIGATE_GPU "Select the GPU type" "None" "Nvidia" "AMD"
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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:frigate instance=@FRIGATE_INSTANCE traefik_host=@FRIGATE_TRAEFIK_HOST http_auth=FRIGATE_HTTP_AUTH http_auth_var=@FRIGATE_HTTP_AUTH ip_sourcerange=@FRIGATE_IP_SOURCERANGE oauth2=FRIGATE_OAUTH2 authorized_group=FRIGATE_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=FRIGATE_MTLS_AUTH mtls_authorized_certs=FRIGATE_MTLS_AUTHORIZED_CERTS hardware_acceleration=FRIGATE_VIDEO_HARDWARE_DEVICE gpu=FRIGATE_GPU

.PHONY: shell
shell:
	@make --no-print-directory docker-compose-shell SERVICE=frigate

.PHONY: show-admin-user # Show the automatically-generated admin login credentials
show-admin-user:
	@echo
	@docker logs frigate-frigate-1 2>&1 | grep -F '***' || echo "Error: admin credentials were not found in logs."
	@echo
