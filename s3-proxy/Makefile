ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure ${ENV_FILE} S3PROXY_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_ask ${ENV_FILE} S3PROXY_TRAEFIK_HOST "Enter the s3-proxy domain name" s3-proxy${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} S3PROXY_S3_ENDPOINT "Enter the s3 endpoint hostname (specify alternate port if not 443. eg. myserver.example.com:8443)" s3.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} S3PROXY_S3_BUCKET "Enter the s3 bucket name to proxy"
	@${BIN}/reconfigure_ask ${ENV_FILE} S3PROXY_S3_ACCESS_KEY_ID "Enter the S3 Access Key"
	@${BIN}/reconfigure_ask ${ENV_FILE} S3PROXY_S3_SECRET_ACCESS_KEY "Enter the S3 Secret Key"
	@${BIN}/reconfigure_auth ${ENV_FILE} S3PROXY

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
	@${BIN}/docker_compose_override ${ENV_FILE} project=:s3proxy instance=@S3PROXY_INSTANCE traefik_host=@S3PROXY_TRAEFIK_HOST http_auth=S3PROXY_HTTP_AUTH http_auth_var=@S3PROXY_HTTP_AUTH ip_sourcerange=@S3PROXY_IP_SOURCERANGE  oauth2=S3PROXY_OAUTH2 authorized_group=S3PROXY_OAUTH2_AUTHORIZED_GROUP


