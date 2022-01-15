ROOT_DIR = ..
include ../_scripts/Makefile.projects

.PHONY: config # Configure .env file
config:
	@${BIN}/reconfigure_ask S3PROXY_TRAEFIK_HOST "Enter the s3-proxy domain name" s3-proxy.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask S3_ENDPOINT "Enter the s3 endpoint hostname"
	@${BIN}/reconfigure_ask S3_BUCKET "Enter the s3 bucket name to proxy"
	@${BIN}/reconfigure_ask S3_ACCESS_KEY_ID "Enter the S3 Access Key"
	@${BIN}/reconfigure_ask S3_SECRET_ACCESS_KEY "Enter the S3 Secret Key"
	@${BIN}/reconfigure_htpasswd S3PROXY_HTTP_AUTH

