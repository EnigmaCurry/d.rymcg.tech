ROOT_DIR = ..
SHELL = /bin/bash
BIN = ${ROOT_DIR}/_scripts

DOCKER_CONTEXT ?= $(shell docker context ls --format "{{.Current}} {{.Name}}" | grep -oP "^true \K.*")
ENV_FILE = .env_${DOCKER_CONTEXT}

.PHONY: all
all: help

.PHONY: help # Show available targets
help:
	@grep -h '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/make \1 \t- \2/'

.PHONY: config # Configure AWS CloudFormation parameters
config:
	@test -f ${ENV_FILE} || cp .env-dist ${ENV_FILE}
	@${BIN}/reconfigure_ask ${ENV_FILE} AWS_INSTANCE_NAME "Enter the instance name (used as DNS subdomain prefix)" docker-dev
	@${BIN}/reconfigure_ask ${ENV_FILE} AWS_ROOT_DOMAIN "Enter the root domain" example.com
	@${BIN}/reconfigure_ask ${ENV_FILE} AWS_KEY_PAIR_NAME "Enter the EC2 key pair name"
	@${BIN}/reconfigure_ask ${ENV_FILE} AWS_INSTANCE_TYPE "Enter the EC2 instance type" t2.small
	@${BIN}/reconfigure_ask ${ENV_FILE} AWS_ROOT_VOLUME_SIZE "Enter root volume size in GB" 10
	@${BIN}/reconfigure_ask ${ENV_FILE} AWS_DOCKER_VOLUME_SIZE "Enter Docker data volume size in GB" 50
	@${BIN}/reconfigure_ask ${ENV_FILE} AWS_SSH_CIDR "Enter CIDR range for SSH access (0.0.0.0/0 = anywhere)" "0.0.0.0/0"
	@${BIN}/reconfigure_ask ${ENV_FILE} AWS_REGION "Enter the AWS region" us-east-1

.PHONY: login # Login to AWS CLI (skips if already authenticated)
login:
	@aws sts get-caller-identity > /dev/null 2>&1 && \
		echo "## Already logged in: $$(aws sts get-caller-identity --query 'Arn' --output text)" || \
		(echo "## Not logged in to AWS CLI." && \
		if aws sso login 2>&1 | grep -q "required SSO configuration"; then \
			echo "## No SSO profile configured. Running 'aws configure sso' ..." && \
			aws configure sso; \
		fi && \
		aws sts get-caller-identity > /dev/null 2>&1 || \
		(echo "## Error: Still not authenticated. Check your AWS CLI configuration." && exit 1))

.PHONY: deploy # Deploy the CloudFormation stack
deploy: check-config login
	@source ${BIN}/funcs.sh && ENV_FILE=${ENV_FILE} && \
	INSTANCE_NAME=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_INSTANCE_NAME) && \
	ROOT_DOMAIN=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_ROOT_DOMAIN) && \
	KEY_PAIR_NAME=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_KEY_PAIR_NAME) && \
	INSTANCE_TYPE=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_INSTANCE_TYPE) && \
	ROOT_VOLUME_SIZE=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_ROOT_VOLUME_SIZE) && \
	DOCKER_VOLUME_SIZE=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_DOCKER_VOLUME_SIZE) && \
	SSH_CIDR=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_SSH_CIDR) && \
	REGION=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_REGION) && \
	ZONE_ID=$$(aws route53 list-hosted-zones-by-name \
		--dns-name "$${ROOT_DOMAIN}" \
		--query 'HostedZones[0].Id' \
		--output text | sed 's|/hostedzone/||') && \
	echo "## Deploying stack: $${INSTANCE_NAME}" && \
	echo "## Domain: $${INSTANCE_NAME}.$${ROOT_DOMAIN}" && \
	echo "## Hosted Zone: $${ZONE_ID}" && \
	aws cloudformation deploy \
		--template-file cloudformation.yaml \
		--stack-name "$${INSTANCE_NAME}" \
		--capabilities CAPABILITY_NAMED_IAM \
		--region "$${REGION}" \
		--parameter-overrides \
			InstanceName="$${INSTANCE_NAME}" \
			RootDomain="$${ROOT_DOMAIN}" \
			HostedZoneId="$${ZONE_ID}" \
			KeyPairName="$${KEY_PAIR_NAME}" \
			InstanceType="$${INSTANCE_TYPE}" \
			RootVolumeSize="$${ROOT_VOLUME_SIZE}" \
			DockerVolumeSize="$${DOCKER_VOLUME_SIZE}" \
			SSHCidr="$${SSH_CIDR}" \
			Region="$${REGION}"

.PHONY: outputs # Show stack outputs (IP, FQDN, ACME keys, etc.)
outputs: check-config
	@INSTANCE_NAME=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_INSTANCE_NAME) && \
	REGION=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_REGION) && \
	aws cloudformation describe-stacks \
		--stack-name "$${INSTANCE_NAME}" \
		--region "$${REGION}" \
		--query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
		--output table

.PHONY: status # Show stack status
status: check-config
	@INSTANCE_NAME=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_INSTANCE_NAME) && \
	REGION=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_REGION) && \
	aws cloudformation describe-stacks \
		--stack-name "$${INSTANCE_NAME}" \
		--region "$${REGION}" \
		--query 'Stacks[0].{Status:StackStatus,Name:StackName,Created:CreationTime}' \
		--output table

.PHONY: destroy # Destroy the CloudFormation stack
destroy: check-config
	@INSTANCE_NAME=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_INSTANCE_NAME) && \
	REGION=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_REGION) && \
	echo "## WARNING: This will destroy the stack: $${INSTANCE_NAME}" && \
	read -p "Are you sure? (y/N): " confirm && \
	[[ "$${confirm}" =~ ^[Yy] ]] && \
	aws cloudformation delete-stack \
		--stack-name "$${INSTANCE_NAME}" \
		--region "$${REGION}" && \
	echo "## Stack deletion initiated: $${INSTANCE_NAME}"

.PHONY: check-config
check-config:
	@test -f ${ENV_FILE} || (echo "## Error: ${ENV_FILE} not found. Run 'make config' first." && exit 1)
	@KEY=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_KEY_PAIR_NAME) && \
	[[ -n "$${KEY}" ]] || (echo "## Error: AWS_KEY_PAIR_NAME is not set. Run 'make config' first." && exit 1)
