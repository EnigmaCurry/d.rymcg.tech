ROOT_DIR = ..
SHELL = /bin/bash
BIN = ${ROOT_DIR}/_scripts

DOCKER_CONTEXT ?= $(shell docker context ls --format "{{.Current}} {{.Name}}" | grep -oP "^true \K.*")
instance ?=
ENV_FILE = .env_${DOCKER_CONTEXT}_$(instance)

.PHONY: all
all: help

.PHONY: help # Show available targets
help:
	@grep -h '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/make \1 \t- \2/'

.PHONY: list # List configured instances for the current context
list:
	@for f in .env_${DOCKER_CONTEXT}_*; do \
		[[ -f "$$f" ]] || continue; \
		INST="$${f#.env_${DOCKER_CONTEXT}_}" && \
		DOMAIN=$$(${BIN}/dotenv -f "$$f" get AWS_ROOT_DOMAIN 2>/dev/null) && \
		REGION=$$(${BIN}/dotenv -f "$$f" get AWS_REGION 2>/dev/null) && \
		echo "$${INST}	$${INST}.$${DOMAIN}	$${REGION}"; \
	done

.PHONY: check-instance
check-instance:
	@if [[ -z "$(instance)" ]]; then \
		readarray -t INSTANCES < <(for f in .env_${DOCKER_CONTEXT}_*; do \
			[[ -f "$$f" ]] || continue; \
			INST="$${f#.env_${DOCKER_CONTEXT}_}"; \
			[[ -n "$${INST}" ]] && echo "$${INST}"; \
		done) && \
		if [[ $${#INSTANCES[@]} -gt 0 && -n "$${INSTANCES[0]}" ]]; then \
			INST=$$(${BIN}/script-wizard choose "Select an instance" "$${INSTANCES[@]}") && \
			exec $(MAKE) --no-print-directory $(MAKECMDGOALS) instance="$${INST}"; \
		else \
			echo "## No instances configured. Usage: make <target> instance=NAME" && \
			exit 1; \
		fi; \
	fi

.PHONY: config # Configure AWS CloudFormation parameters (instance=NAME required)
config:
	@if [[ -z "$(instance)" ]]; then \
		readarray -t INSTANCES < <(for f in .env_${DOCKER_CONTEXT}_*; do \
			[[ -f "$$f" ]] || continue; \
			INST="$${f#.env_${DOCKER_CONTEXT}_}"; \
			[[ -n "$${INST}" ]] && echo "$${INST}"; \
		done) && \
		INSTANCES+=("(create new)") && \
		INST=$$(${BIN}/script-wizard choose "Select an instance" "$${INSTANCES[@]}") && \
		if [[ "$${INST}" == "(create new)" ]]; then \
			read -e -p "Enter new instance name: " INST && \
			[[ -n "$${INST}" ]] || (echo "## Error: instance name required." && exit 1); \
		fi && \
		exec $(MAKE) --no-print-directory config instance="$${INST}"; \
	fi
	@test -f ${ENV_FILE} || cp .env-dist ${ENV_FILE}
	@${BIN}/dotenv -f ${ENV_FILE} set AWS_INSTANCE_NAME="$(instance)"
	@${BIN}/reconfigure_ask ${ENV_FILE} AWS_ROOT_DOMAIN "Enter the root domain" example.com
	@CURRENT_REGION=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_REGION 2>/dev/null || echo us-east-1) && \
	readarray -t REGIONS < <(aws ec2 describe-regions \
		--query 'Regions[*].RegionName' \
		--output text | tr '\t' '\n' | sort) && \
	REGION=$$(${BIN}/script-wizard choose "Select the AWS region" "$${REGIONS[@]}" \
		--default "$${CURRENT_REGION}") && \
	${BIN}/dotenv -f ${ENV_FILE} set AWS_REGION="$${REGION}"
	@CURRENT_KEY=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_KEY_PAIR_NAME 2>/dev/null) && \
	if [[ -n "$${CURRENT_KEY}" ]]; then \
		DEFAULT_KEY_CHOICE="Use an existing key pair"; \
	else \
		DEFAULT_KEY_CHOICE="Create a new key pair"; \
	fi && \
	CHOICE=$$(${BIN}/script-wizard choose \
		"SSH key pair for EC2 instance" \
		"Create a new key pair" \
		"Use an existing key pair" \
		--default "$${DEFAULT_KEY_CHOICE}") && \
	if [[ "$${CHOICE}" == "Create a new key pair" ]]; then \
		INSTANCE_NAME=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_INSTANCE_NAME) && \
		KEY_NAME="$${INSTANCE_NAME}-$$(openssl rand -hex 4)" && \
		KEY_FILE="$$HOME/.ssh/$${KEY_NAME}" && \
		ssh-keygen -t ed25519 -f "$${KEY_FILE}" -N "" -C "$${KEY_NAME}" && \
		REGION=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_REGION || echo us-east-1) && \
		aws ec2 import-key-pair \
			--key-name "$${KEY_NAME}" \
			--public-key-material fileb://$${KEY_FILE}.pub \
			--region "$${REGION}" && \
		echo "## Key pair created: $${KEY_NAME}" && \
		echo "## Private key: $${KEY_FILE}" && \
		${BIN}/dotenv -f ${ENV_FILE} set AWS_KEY_PAIR_NAME="$${KEY_NAME}"; \
	else \
		REGION=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_REGION || echo us-east-1) && \
		readarray -t KEYS < <(aws ec2 describe-key-pairs \
			--region "$${REGION}" \
			--query 'KeyPairs[*].KeyName' \
			--output text | tr '\t' '\n' | sort) && \
		if [[ $${#KEYS[@]} -eq 0 ]]; then \
			echo "## Error: No key pairs found in region $${REGION}." && exit 1; \
		fi && \
		KEY_NAME=$$(${BIN}/script-wizard choose "Select a key pair" "$${KEYS[@]}" \
			--default "$${CURRENT_KEY}") && \
		${BIN}/dotenv -f ${ENV_FILE} set AWS_KEY_PAIR_NAME="$${KEY_NAME}"; \
	fi
	@${BIN}/reconfigure_ask ${ENV_FILE} AWS_INSTANCE_TYPE "Enter the EC2 instance type" t2.small
	@${BIN}/reconfigure_ask ${ENV_FILE} AWS_ROOT_VOLUME_SIZE "Enter root volume size in GB" 10
	@${BIN}/reconfigure_ask ${ENV_FILE} AWS_DOCKER_VOLUME_SIZE "Enter Docker data volume size in GB" 50
	@${BIN}/reconfigure_ask ${ENV_FILE} AWS_SSH_CIDR "Enter CIDR range for SSH access (0.0.0.0/0 = anywhere)" "0.0.0.0/0"

.PHONY: login # Login to AWS CLI (skips if already authenticated)
login:
	@aws sts get-caller-identity > /dev/null 2>&1 && \
		echo "## Already logged in: $$(aws sts get-caller-identity --query 'Arn' --output text)" || \
		(echo "## Not logged in to AWS CLI." && \
		echo "## Choose an authentication method:" && \
		METHOD=$$(${BIN}/script-wizard choose \
			"How do you authenticate with AWS?" \
			"Access keys (IAM user)" \
			"SSO (IAM Identity Center)" \
			--default "Access keys (IAM user)") && \
		if [[ "$${METHOD}" == "Access keys (IAM user)" ]]; then \
			aws configure; \
		else \
			aws sso login 2>&1 | grep -q "required SSO configuration" && \
				aws configure sso || aws sso login; \
		fi && \
		aws sts get-caller-identity > /dev/null 2>&1 || \
		(echo "## Error: Still not authenticated. Check your AWS CLI configuration." && exit 1))

.PHONY: deploy # Deploy the CloudFormation stack
deploy: check-instance check-config login
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
			Region="$${REGION}" && \
	$(MAKE) --no-print-directory ssh-config

.PHONY: ssh-config # Add/update SSH config entry for the EC2 instance
ssh-config: check-instance check-config
	@INSTANCE_NAME=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_INSTANCE_NAME) && \
	KEY_PAIR_NAME=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_KEY_PAIR_NAME) && \
	ROOT_DOMAIN=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_ROOT_DOMAIN) && \
	REGION=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_REGION) && \
	FQDN="$${INSTANCE_NAME}.$${ROOT_DOMAIN}" && \
	KEY_FILE="$$HOME/.ssh/$${KEY_PAIR_NAME}" && \
	SSH_CONFIG="$$HOME/.ssh/config" && \
	mkdir -p "$$HOME/.ssh" && chmod 700 "$$HOME/.ssh" && \
	touch "$${SSH_CONFIG}" && chmod 600 "$${SSH_CONFIG}" && \
	ENTRY=$$(printf 'Host %s\n    Hostname %s\n    User admin\n    IdentityFile %s\n' \
		"$${INSTANCE_NAME}" "$${FQDN}" "$${KEY_FILE}") && \
	if grep -q "^Host $${INSTANCE_NAME}$$" "$${SSH_CONFIG}" 2>/dev/null; then \
		echo "## Updating existing SSH config entry: $${INSTANCE_NAME}" && \
		sed -i "/^Host $${INSTANCE_NAME}$$/,/^Host \|^$$/d" "$${SSH_CONFIG}" && \
		echo "$${ENTRY}" >> "$${SSH_CONFIG}"; \
	else \
		echo "## Adding SSH config entry: $${INSTANCE_NAME}" && \
		printf '\n%s\n' "$${ENTRY}" >> "$${SSH_CONFIG}"; \
	fi && \
	echo "## SSH: ssh $${INSTANCE_NAME}"

.PHONY: outputs # Show stack outputs (IP, FQDN, ACME keys, etc.)
outputs: check-instance check-config
	@INSTANCE_NAME=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_INSTANCE_NAME) && \
	REGION=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_REGION) && \
	aws cloudformation describe-stacks \
		--stack-name "$${INSTANCE_NAME}" \
		--region "$${REGION}" \
		--query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
		--output table

.PHONY: status # Show stack status
status: check-instance check-config
	@INSTANCE_NAME=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_INSTANCE_NAME) && \
	REGION=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_REGION) && \
	aws cloudformation describe-stacks \
		--stack-name "$${INSTANCE_NAME}" \
		--region "$${REGION}" \
		--query 'Stacks[0].{Status:StackStatus,Name:StackName,Created:CreationTime}' \
		--output table

.PHONY: destroy # Destroy the CloudFormation stack
destroy: check-instance check-config
	@INSTANCE_NAME=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_INSTANCE_NAME) && \
	REGION=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_REGION) && \
	echo "## WARNING: This will destroy the stack: $${INSTANCE_NAME}" && \
	read -p "Are you sure? (y/N): " confirm && \
	[[ "$${confirm}" =~ ^[Yy] ]] && \
	aws cloudformation delete-stack \
		--stack-name "$${INSTANCE_NAME}" \
		--region "$${REGION}" && \
	echo "## Waiting for stack deletion: $${INSTANCE_NAME} ..." && \
	aws cloudformation wait stack-delete-complete \
		--stack-name "$${INSTANCE_NAME}" \
		--region "$${REGION}" && \
	echo "## Stack deleted: $${INSTANCE_NAME}"

.PHONY: cleanup-volumes # Delete orphaned EBS volumes (prompts for each)
cleanup-volumes:
	@REGION=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_REGION 2>/dev/null || echo us-east-1) && \
	readarray -t VOLS < <(aws ec2 describe-volumes \
		--region "$${REGION}" \
		--filters Name=status,Values=available \
		--query 'Volumes[*].[VolumeId,Size,CreateTime]' \
		--output text) && \
	if [[ $${#VOLS[@]} -eq 0 || -z "$${VOLS[0]}" ]]; then \
		echo "## No orphaned volumes found in $${REGION}."; \
	else \
		for line in "$${VOLS[@]}"; do \
			VOL_ID=$$(echo "$${line}" | awk '{print $$1}') && \
			SIZE=$$(echo "$${line}" | awk '{print $$2}') && \
			CREATED=$$(echo "$${line}" | awk '{print $$3}') && \
			echo "" && \
			echo "## Volume: $${VOL_ID}  Size: $${SIZE}GB  Created: $${CREATED}" && \
			read -p "Delete this volume? (y/N): " confirm && \
			if [[ "$${confirm}" =~ ^[Yy] ]]; then \
				aws ec2 delete-volume --region "$${REGION}" --volume-id "$${VOL_ID}" && \
				echo "## Deleted: $${VOL_ID}"; \
			else \
				echo "## Skipped: $${VOL_ID}"; \
			fi; \
		done; \
	fi

.PHONY: check-config
check-config:
	@test -f ${ENV_FILE} || (echo "## Error: ${ENV_FILE} not found. Run 'make config' first." && exit 1)
	@KEY=$$(${BIN}/dotenv -f ${ENV_FILE} get AWS_KEY_PAIR_NAME) && \
	[[ -n "$${KEY}" ]] || (echo "## Error: AWS_KEY_PAIR_NAME is not set. Run 'make config' first." && exit 1)
