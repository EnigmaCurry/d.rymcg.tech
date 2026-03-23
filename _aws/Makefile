ROOT_DIR = ..
SHELL = /bin/bash
BIN = ${ROOT_DIR}/_scripts

DOCKER_CONTEXT ?= $(shell docker context ls --format "{{.Current}} {{.Name}}" | grep -oP "^true \K.*")
instance ?=
SELECT_INSTANCE = ./select-instance.sh "$(instance)" "${DOCKER_CONTEXT}" "${BIN}"
ifdef DRT_ENV_DIR
env_file = ${DRT_ENV_DIR}/_aws/.env_${DOCKER_CONTEXT}_$${INST}
else
env_file = .env_${DOCKER_CONTEXT}_$${INST}
endif

.PHONY: all
all: help

.PHONY: help # Show available targets
help:
	@grep -h '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/make \1 \t- \2/'

.PHONY: list # List configured instances for the current context
list:
ifdef DRT_ENV_DIR
	@_ENV_DIR="${DRT_ENV_DIR}/_aws"; \
	for f in $${_ENV_DIR}/.env_${DOCKER_CONTEXT}_*; do \
		[[ -f "$$f" ]] || continue; \
		INST="$$(basename "$$f")" && INST="$${INST#.env_${DOCKER_CONTEXT}_}" && \
		DOMAIN=$$(${BIN}/dotenv -f "$$f" get AWS_ROOT_DOMAIN 2>/dev/null) && \
		REGION=$$(${BIN}/dotenv -f "$$f" get AWS_REGION 2>/dev/null) && \
		echo "$${INST}	$${INST}.$${DOMAIN}	$${REGION}"; \
	done
else
	@for f in .env_${DOCKER_CONTEXT}_*; do \
		[[ -f "$$f" ]] || continue; \
		INST="$${f#.env_${DOCKER_CONTEXT}_}" && \
		DOMAIN=$$(${BIN}/dotenv -f "$$f" get AWS_ROOT_DOMAIN 2>/dev/null) && \
		REGION=$$(${BIN}/dotenv -f "$$f" get AWS_REGION 2>/dev/null) && \
		echo "$${INST}	$${INST}.$${DOMAIN}	$${REGION}"; \
	done
endif

.PHONY: config # Configure AWS CloudFormation parameters (instance=NAME)
config:
	@INST=$$(${SELECT_INSTANCE} --create) && \
	ENV=${env_file} && \
	mkdir -p "$$(dirname $${ENV})" 2>/dev/null; \
	test -f $${ENV} || cp .env-dist $${ENV} && \
	${BIN}/dotenv -f $${ENV} set AWS_INSTANCE_NAME="$${INST}" && \
	CURRENT_DOMAIN=$$(${BIN}/dotenv -f $${ENV} get AWS_ROOT_DOMAIN 2>/dev/null) && \
	readarray -t ZONES < <(aws route53 list-hosted-zones \
		--query 'HostedZones[*].Name' --output text | tr '\t' '\n' | sed 's/\.$$//' | sort) && \
	if [[ $${#ZONES[@]} -gt 0 ]]; then \
		DOMAIN=$$(${BIN}/script-wizard choose "Select the Route53 domain" "$${ZONES[@]}" \
			$${CURRENT_DOMAIN:+--default "$${CURRENT_DOMAIN}"}); \
	else \
		echo "No Route53 hosted zones found. Enter domain manually:" >&2; \
		read -e -p "AWS_ROOT_DOMAIN: " DOMAIN; \
	fi && \
	${BIN}/dotenv -f $${ENV} set AWS_ROOT_DOMAIN="$${DOMAIN}" && \
	CURRENT_REGION=$$(${BIN}/dotenv -f $${ENV} get AWS_REGION 2>/dev/null || echo us-east-1) && \
	readarray -t REGIONS < <(aws ec2 describe-regions \
		--query 'Regions[*].RegionName' \
		--output text | tr '\t' '\n' | sort) && \
	REGION=$$(${BIN}/script-wizard choose "Select the AWS region" "$${REGIONS[@]}" \
		--default "$${CURRENT_REGION}") && \
	${BIN}/dotenv -f $${ENV} set AWS_REGION="$${REGION}" && \
	CURRENT_DEB=$$(${BIN}/dotenv -f $${ENV} get AWS_DEBIAN_VERSION 2>/dev/null || echo 13) && \
	DEB_CHOICE=$$(${BIN}/script-wizard choose "Select Debian version" \
		"Debian 13 (trixie)" "Debian 12 (bookworm)" \
		--default "Debian $${CURRENT_DEB}") && \
	DEB_VER=$$(echo "$${DEB_CHOICE}" | grep -oP '[0-9]+') && \
	(grep -q '^AWS_DEBIAN_VERSION=' $${ENV} || echo "AWS_DEBIAN_VERSION=13" >> $${ENV}) && \
	${BIN}/dotenv -f $${ENV} set AWS_DEBIAN_VERSION="$${DEB_VER}" && \
	CURRENT_KEY=$$(${BIN}/dotenv -f $${ENV} get AWS_KEY_PAIR_NAME 2>/dev/null) && \
	REGION=$$(${BIN}/dotenv -f $${ENV} get AWS_REGION || echo us-east-1) && \
	if [[ -n "$${CURRENT_KEY}" ]]; then \
		DEFAULT_KEY_CHOICE="Use existing key pair (AWS)"; \
	else \
		DEFAULT_KEY_CHOICE="Create a new key pair"; \
	fi && \
	CHOICE=$$(${BIN}/script-wizard choose \
		"SSH key pair for EC2 instance" \
		"Use existing key pair (AWS)" \
		"Import from ssh-agent" \
		"Create a new key pair" \
		--default "$${DEFAULT_KEY_CHOICE}") && \
	if [[ "$${CHOICE}" == "Create a new key pair" ]]; then \
		INSTANCE_NAME=$$(${BIN}/dotenv -f $${ENV} get AWS_INSTANCE_NAME) && \
		KEY_NAME="$${INSTANCE_NAME}-$$(openssl rand -hex 4)" && \
		KEY_FILE="$$HOME/.ssh/$${KEY_NAME}" && \
		ssh-keygen -t ed25519 -f "$${KEY_FILE}" -N "" -C "$${KEY_NAME}" && \
		aws ec2 import-key-pair \
			--key-name "$${KEY_NAME}" \
			--public-key-material fileb://$${KEY_FILE}.pub \
			--region "$${REGION}" && \
		echo "## Key pair created: $${KEY_NAME}" && \
		echo "## Private key: $${KEY_FILE}" && \
		${BIN}/dotenv -f $${ENV} set AWS_KEY_PAIR_NAME="$${KEY_NAME}"; \
	elif [[ "$${CHOICE}" == "Import from ssh-agent" ]]; then \
		readarray -t ALL_AGENT_KEYS < <(ssh-add -L 2>/dev/null) && \
		AGENT_KEYS=() && \
		SKIPPED=0 && \
		for key in "$${ALL_AGENT_KEYS[@]}"; do \
			KEY_TYPE=$$(echo "$${key}" | awk '{print $$1}') && \
			if [[ "$${KEY_TYPE}" == sk-* ]]; then \
				SKIPPED=$$((SKIPPED + 1)); \
			else \
				AGENT_KEYS+=("$${key}"); \
			fi; \
		done && \
		if [[ $${SKIPPED} -gt 0 ]]; then \
			echo "## Note: $${SKIPPED} FIDO2/SK key(s) skipped (not supported by EC2)."; \
		fi && \
		if [[ $${#AGENT_KEYS[@]} -eq 0 ]]; then \
			echo "## Error: No compatible keys found in ssh-agent (SK keys not supported by EC2)." && \
			echo "## Use 'Create a new key pair' instead." && exit 1; \
		fi && \
		AGENT_LABELS=() && \
		for key in "$${AGENT_KEYS[@]}"; do \
			LABEL=$$(echo "$${key}" | awk '{print $$NF " (" $$1 ")"}') && \
			AGENT_LABELS+=("$${LABEL}"); \
		done && \
		SELECTED=$$(${BIN}/script-wizard choose "Select a key from ssh-agent" "$${AGENT_LABELS[@]}") && \
		for i in "$${!AGENT_LABELS[@]}"; do \
			if [[ "$${AGENT_LABELS[$$i]}" == "$${SELECTED}" ]]; then \
				PUB_KEY="$${AGENT_KEYS[$$i]}"; \
				break; \
			fi; \
		done && \
		KEY_COMMENT=$$(echo "$${PUB_KEY}" | awk '{print $$NF}') && \
		KEY_NAME="$${KEY_COMMENT}" && \
		echo "$${PUB_KEY}" > /tmp/$${KEY_NAME}.pub && \
		aws ec2 import-key-pair \
			--key-name "$${KEY_NAME}" \
			--public-key-material fileb:///tmp/$${KEY_NAME}.pub \
			--region "$${REGION}" && \
		rm -f /tmp/$${KEY_NAME}.pub && \
		echo "## Key imported from ssh-agent: $${KEY_NAME}" && \
		${BIN}/dotenv -f $${ENV} set AWS_KEY_PAIR_NAME="$${KEY_NAME}"; \
	else \
		readarray -t KEYS < <(aws ec2 describe-key-pairs \
			--region "$${REGION}" \
			--query 'KeyPairs[*].KeyName' \
			--output text | tr '\t' '\n' | sort) && \
		if [[ $${#KEYS[@]} -eq 0 ]]; then \
			echo "## Error: No key pairs found in region $${REGION}." && exit 1; \
		fi && \
		KEY_NAME=$$(${BIN}/script-wizard choose "Select a key pair" "$${KEYS[@]}" \
			--default "$${CURRENT_KEY}") && \
		${BIN}/dotenv -f $${ENV} set AWS_KEY_PAIR_NAME="$${KEY_NAME}"; \
	fi && \
	CURRENT_TYPE=$$(${BIN}/dotenv -f $${ENV} get AWS_INSTANCE_TYPE 2>/dev/null || echo t2.small) && \
	echo "## Pricing: https://aws.amazon.com/ec2/pricing/on-demand/" && \
	readarray -t INSTANCE_TYPES < <(aws ec2 describe-instance-types \
		--region "$${REGION}" \
		--filters "Name=instance-type,Values=t2.*,t3.*,t3a.*,m6i.*,m7i.*,c6i.*,r6i.*" \
		--query 'InstanceTypes[*].[InstanceType,VCpuInfo.DefaultVCpus,MemoryInfo.SizeInMiB]' \
		--output text | sort -k3 -n | awk '{printf "%s (%d vCPU, %.1f GB)\n", $$1, $$2, $$3/1024}') && \
	DEFAULT_TYPE_LABEL=$$(for t in "$${INSTANCE_TYPES[@]}"; do \
		[[ "$${t%% *}" == "$${CURRENT_TYPE}" ]] && echo "$$t" && break; \
	done) && \
	SELECTED=$$(${BIN}/script-wizard choose "Select EC2 instance type" "$${INSTANCE_TYPES[@]}" \
		--default "$${DEFAULT_TYPE_LABEL:-$${CURRENT_TYPE}}") && \
	INSTANCE_TYPE=$$(echo "$${SELECTED}" | awk '{print $$1}') && \
	${BIN}/dotenv -f $${ENV} set AWS_INSTANCE_TYPE="$${INSTANCE_TYPE}" && \
	ROOT_VOL=$$(${BIN}/dotenv -f $${ENV} get AWS_ROOT_VOLUME_SIZE 2>/dev/null || true) && \
	DOCKER_VOL=$$(${BIN}/dotenv -f $${ENV} get AWS_DOCKER_VOLUME_SIZE 2>/dev/null || true) && \
	if [[ -z "$${ROOT_VOL}" || "$${ROOT_VOL}" == "10" && -z "$${DOCKER_VOL}" || "$${DOCKER_VOL}" == "50" ]] && \
	   ! aws cloudformation describe-stacks --stack-name "$$(${BIN}/dotenv -f $${ENV} get AWS_INSTANCE_NAME)" --region "$${REGION}" > /dev/null 2>&1; then \
		${BIN}/reconfigure_ask $${ENV} AWS_ROOT_VOLUME_SIZE "Enter root volume size in GB" 10 && \
		${BIN}/reconfigure_ask $${ENV} AWS_DOCKER_VOLUME_SIZE "Enter Docker data volume size in GB" 50; \
	else \
		echo "## Volume sizes: root=$${ROOT_VOL}GB, docker=$${DOCKER_VOL}GB (use 'resize-volume' to change)"; \
	fi && \
	${BIN}/reconfigure_ask $${ENV} AWS_SSH_CIDR "Enter CIDR range for SSH access (0.0.0.0/0 = anywhere)" "0.0.0.0/0" && \
	CURRENT_PORTS=$$(${BIN}/dotenv -f $${ENV} get AWS_OPEN_PORTS 2>/dev/null || true) && \
	PORT_OPTIONS=( \
		"acme-dns:53 TCP+UDP, 2890 TCP, DNS delegation (acme-dns)" \
		"forgejo-ssh:2222 TCP (Forgejo SSH)" \
		"sftp:2223 TCP (SFTP)" \
		"iperf:5201 TCP+UDP (Iperf)" \
		"xmpp:5222,5269 TCP (XMPP)" \
		"irc:6697,6698 TCP (IRC)" \
		"web-plain:8000 TCP (HTTP non-TLS)" \
		"mqtt:8883 TCP (Mosquitto MQTT)" \
		"rtmp:1935 TCP (RTMP)" \
		"snapcast:1704,1705 TCP (Snapcast)" \
		"redis:6380 TCP (Redis)" \
		"mpd:6600 TCP (MPD/Mopidy)" \
		"postgresql:5432 TCP (PostgreSQL mTLS)" \
		"jitsi:10000 UDP (Jitsi WebRTC)" \
		"wireguard:51820 UDP (Wireguard VPN)" \
	) && \
	DEFAULT_JSON="[]" && \
	if [[ -n "$${CURRENT_PORTS}" ]]; then \
		DEFAULT_JSON=$$(echo "$${CURRENT_PORTS}" | tr ',' '\n' | while read -r p; do \
			for opt in "$${PORT_OPTIONS[@]}"; do \
				[[ "$${opt%%:*}" == "$$p" ]] && echo "$$opt"; \
			done; \
		done | jq -R . | jq -s -c .); \
	fi && \
	SELECTED=$$(${BIN}/script-wizard select \
		--default "$${DEFAULT_JSON}" \
		"Select additional ports to open (SSH, HTTP, HTTPS always open):" \
		"$${PORT_OPTIONS[@]}") && \
	PORTS=$$(echo "$${SELECTED}" | while read -r line; do echo "$${line%%:*}"; done | paste -sd,) && \
	${BIN}/dotenv -f $${ENV} set AWS_OPEN_PORTS="$${PORTS}" || \
	${BIN}/dotenv -f $${ENV} set AWS_OPEN_PORTS=""

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
deploy: login
	@INST=$$(${SELECT_INSTANCE}) && \
	ENV=${env_file} && \
	test -f $${ENV} || (echo "## Error: $${ENV} not found. Run 'make config' first." && exit 1) && \
	INSTANCE_NAME=$$(${BIN}/dotenv -f $${ENV} get AWS_INSTANCE_NAME) && \
	ROOT_DOMAIN=$$(${BIN}/dotenv -f $${ENV} get AWS_ROOT_DOMAIN) && \
	KEY_PAIR_NAME=$$(${BIN}/dotenv -f $${ENV} get AWS_KEY_PAIR_NAME) && \
	INSTANCE_TYPE=$$(${BIN}/dotenv -f $${ENV} get AWS_INSTANCE_TYPE) && \
	ROOT_VOLUME_SIZE=$$(${BIN}/dotenv -f $${ENV} get AWS_ROOT_VOLUME_SIZE) && \
	DOCKER_VOLUME_SIZE=$$(${BIN}/dotenv -f $${ENV} get AWS_DOCKER_VOLUME_SIZE) && \
	SSH_CIDR=$$(${BIN}/dotenv -f $${ENV} get AWS_SSH_CIDR) && \
	REGION=$$(${BIN}/dotenv -f $${ENV} get AWS_REGION) && \
	OPEN_PORTS=$$(${BIN}/dotenv -f $${ENV} get AWS_OPEN_PORTS 2>/dev/null || echo "") && \
	DEB_VER=$$(${BIN}/dotenv -f $${ENV} get AWS_DEBIAN_VERSION 2>/dev/null || echo 13) && \
	ZONE_ID=$$(aws route53 list-hosted-zones-by-name \
		--dns-name "$${ROOT_DOMAIN}" \
		--query 'HostedZones[0].Id' \
		--output text | sed 's|/hostedzone/||') && \
	PORT_PARAMS="" && \
	for port in $$(echo "$${OPEN_PORTS}" | tr ',' ' '); do \
		case "$${port}" in \
			acme-dns) PORT_PARAMS="$${PORT_PARAMS} EnableAcmeDns=true";; \
			forgejo-ssh) PORT_PARAMS="$${PORT_PARAMS} EnableForgejoSSH=true";; \
			sftp) PORT_PARAMS="$${PORT_PARAMS} EnableSFTP=true";; \
			iperf) PORT_PARAMS="$${PORT_PARAMS} EnableIperf=true";; \
			xmpp) PORT_PARAMS="$${PORT_PARAMS} EnableXMPP=true";; \
			irc) PORT_PARAMS="$${PORT_PARAMS} EnableIRC=true";; \
			web-plain) PORT_PARAMS="$${PORT_PARAMS} EnableWebPlain=true";; \
			mqtt) PORT_PARAMS="$${PORT_PARAMS} EnableMQTT=true";; \
			rtmp) PORT_PARAMS="$${PORT_PARAMS} EnableRTMP=true";; \
			snapcast) PORT_PARAMS="$${PORT_PARAMS} EnableSnapcast=true";; \
			redis) PORT_PARAMS="$${PORT_PARAMS} EnableRedis=true";; \
			mpd) PORT_PARAMS="$${PORT_PARAMS} EnableMPD=true";; \
			postgresql) PORT_PARAMS="$${PORT_PARAMS} EnablePostgreSQL=true";; \
			jitsi) PORT_PARAMS="$${PORT_PARAMS} EnableJitsi=true";; \
			wireguard) PORT_PARAMS="$${PORT_PARAMS} EnableWireguard=true";; \
		esac; \
	done && \
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
			Region="$${REGION}" \
			DebianAMI="/aws/service/debian/release/$${DEB_VER}/latest/amd64" \
			$${PORT_PARAMS} && \
	$(MAKE) --no-print-directory ssh-config instance="$${INST}"

.PHONY: ssh-config # Add/update SSH config entry for the EC2 instance
ssh-config:
	@INST=$$(${SELECT_INSTANCE}) && \
	ENV=${env_file} && \
	INSTANCE_NAME=$$(${BIN}/dotenv -f $${ENV} get AWS_INSTANCE_NAME) && \
	KEY_PAIR_NAME=$$(${BIN}/dotenv -f $${ENV} get AWS_KEY_PAIR_NAME) && \
	ROOT_DOMAIN=$$(${BIN}/dotenv -f $${ENV} get AWS_ROOT_DOMAIN) && \
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

.PHONY: firewall # Show security group inbound rules
firewall:
	@INST=$$(${SELECT_INSTANCE}) && \
	ENV=${env_file} && \
	INSTANCE_NAME=$$(${BIN}/dotenv -f $${ENV} get AWS_INSTANCE_NAME) && \
	REGION=$$(${BIN}/dotenv -f $${ENV} get AWS_REGION) && \
	SG_ID=$$(aws ec2 describe-security-groups \
		--region "$${REGION}" \
		--filters "Name=tag:aws:cloudformation:stack-name,Values=$${INSTANCE_NAME}" \
		--query 'SecurityGroups[0].GroupId' \
		--output text) && \
	echo "## Firewall rules for $${INSTANCE_NAME} ($${SG_ID}):" && \
	aws ec2 describe-security-group-rules \
		--region "$${REGION}" \
		--filters "Name=group-id,Values=$${SG_ID}" \
		--output json | \
		jq -r '.SecurityGroupRules | map(select(.IsEgress == false)) | sort_by(.FromPort) | ["Port","Proto","CIDR","Description"], (.[] | ["\(.FromPort)-\(.ToPort)", .IpProtocol, .CidrIpv4, .Description]) | @tsv' | \
		column -t -s$$'\t'

.PHONY: outputs # Show stack outputs (IP, FQDN, ACME keys, etc.)
outputs:
	@INST=$$(${SELECT_INSTANCE}) && \
	ENV=${env_file} && \
	INSTANCE_NAME=$$(${BIN}/dotenv -f $${ENV} get AWS_INSTANCE_NAME) && \
	REGION=$$(${BIN}/dotenv -f $${ENV} get AWS_REGION) && \
	aws cloudformation describe-stacks \
		--stack-name "$${INSTANCE_NAME}" \
		--region "$${REGION}" \
		--query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
		--output table

.PHONY: status # Show stack status
status:
	@INST=$$(${SELECT_INSTANCE}) && \
	ENV=${env_file} && \
	INSTANCE_NAME=$$(${BIN}/dotenv -f $${ENV} get AWS_INSTANCE_NAME) && \
	REGION=$$(${BIN}/dotenv -f $${ENV} get AWS_REGION) && \
	aws cloudformation describe-stacks \
		--stack-name "$${INSTANCE_NAME}" \
		--region "$${REGION}" \
		--query 'Stacks[0].{Status:StackStatus,Name:StackName,Created:CreationTime}' \
		--output table && \
	STACK_JSON=$$(aws cloudformation describe-stacks \
		--stack-name "$${INSTANCE_NAME}" \
		--region "$${REGION}" \
		--output json) && \
	PUBLIC_IP=$$(echo "$${STACK_JSON}" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="PublicIP") | .OutputValue') && \
	FQDN=$$(echo "$${STACK_JSON}" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="FQDN") | .OutputValue') && \
	INSTANCE_ID=$$(echo "$${STACK_JSON}" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="InstanceId") | .OutputValue') && \
	INSTANCE_JSON=$$(aws ec2 describe-instances \
		--region "$${REGION}" \
		--instance-ids "$${INSTANCE_ID}" \
		--query 'Reservations[0].Instances[0]' \
		--output json 2>/dev/null) && \
	PRIVATE_IP=$$(echo "$${INSTANCE_JSON}" | jq -r '.PrivateIpAddress // "N/A"') && \
	AMI_ID=$$(echo "$${INSTANCE_JSON}" | jq -r '.ImageId // "N/A"') && \
	AMI_NAME=$$(aws ec2 describe-images \
		--region "$${REGION}" \
		--image-ids "$${AMI_ID}" \
		--query 'Images[0].Name' \
		--output text 2>/dev/null || echo "N/A") && \
	echo "## Public IP: $${PUBLIC_IP}" && \
	echo "## Private IP: $${PRIVATE_IP}" && \
	echo "## FQDN: $${FQDN}" && \
	echo "## AMI: $${AMI_ID} ($${AMI_NAME})"

.PHONY: destroy # Destroy the CloudFormation stack
destroy:
	@INST=$$(${SELECT_INSTANCE}) && \
	ENV=${env_file} && \
	INSTANCE_NAME=$$(${BIN}/dotenv -f $${ENV} get AWS_INSTANCE_NAME) && \
	REGION=$$(${BIN}/dotenv -f $${ENV} get AWS_REGION) && \
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
	echo "## Stack deleted: $${INSTANCE_NAME}" && \
	echo "" && \
	echo "## Note: EBS data volumes are preserved after stack deletion." && \
	echo "## Run 'd.rymcg.tech aws cleanup-volumes' to review and delete orphaned volumes."

.PHONY: acme-dns-cname # Create Route53 CNAME records for acme-dns ACME challenges
acme-dns-cname:
	@INST=$$(${SELECT_INSTANCE}) && \
	ENV=${env_file} && \
	INSTANCE_NAME=$$(${BIN}/dotenv -f $${ENV} get AWS_INSTANCE_NAME) && \
	ROOT_DOMAIN=$$(${BIN}/dotenv -f $${ENV} get AWS_ROOT_DOMAIN) && \
	REGION=$$(${BIN}/dotenv -f $${ENV} get AWS_REGION) && \
	FQDN="$${INSTANCE_NAME}.$${ROOT_DOMAIN}" && \
	FULLDOMAIN=$$(docker --context "$${INSTANCE_NAME}" compose \
		--project-name traefik \
		exec acme-sh cat /acme.sh/acmedns-account.json 2>/dev/null \
		| jq -r '.fulldomain') && \
	if [[ -z "$${FULLDOMAIN}" || "$${FULLDOMAIN}" == "null" ]]; then \
		echo "## Error: No acme-dns registration found." && \
		echo "## Run 'd.rymcg.tech make traefik acme-sh-register' first." && \
		exit 1; \
	fi && \
	ZONE_ID=$$(aws route53 list-hosted-zones-by-name \
		--dns-name "$${ROOT_DOMAIN}" \
		--query 'HostedZones[0].Id' \
		--output text | sed 's|/hostedzone/||') && \
	CERT_DOMAINS=$$(docker --context "$${INSTANCE_NAME}" compose \
		--project-name traefik \
		exec acme-sh sh -c 'echo $${TRAEFIK_ACME_CERT_DOMAINS}' 2>/dev/null) && \
	readarray -t DOMAINS < <(echo "$${CERT_DOMAINS}" | jq -r '.[] | [.[0]] + (.[1] // []) | .[] | if startswith("*.") then .[2:] else . end' | sort -u) && \
	echo "## acme-dns fulldomain: $${FULLDOMAIN}" && \
	echo "## Hosted Zone: $${ZONE_ID}" && \
	echo "" && \
	CHANGES='[]' && \
	for DOMAIN in "$${DOMAINS[@]}"; do \
		CNAME="_acme-challenge.$${DOMAIN}" && \
		echo "## Creating CNAME: $${CNAME} -> $${FULLDOMAIN}" && \
		CHANGES=$$(echo "$${CHANGES}" | jq --arg name "$${CNAME}" --arg target "$${FULLDOMAIN}" \
			'. + [{"Action":"UPSERT","ResourceRecordSet":{"Name":$$name,"Type":"CNAME","TTL":300,"ResourceRecords":[{"Value":$$target}]}}]'); \
	done && \
	BATCH=$$(echo "$${CHANGES}" | jq '{Changes:.}') && \
	aws route53 change-resource-record-sets \
		--hosted-zone-id "$${ZONE_ID}" \
		--change-batch "$${BATCH}" \
		--region "$${REGION}" \
		--query 'ChangeInfo.{Status:Status,Id:Id}' \
		--output table && \
	echo "" && \
	echo "## CNAME records created. Waiting for DNS propagation..." && \
	echo "## Then restart acme-sh: d.rymcg.tech make traefik restart service=acme-sh"

.PHONY: estimate # Show cost estimate for the configured stack
estimate:
	@INST=$$(${SELECT_INSTANCE}) && \
	ENV=${env_file} && \
	./estimate.sh \
		"$$(${BIN}/dotenv -f $${ENV} get AWS_INSTANCE_TYPE)" \
		"$$(${BIN}/dotenv -f $${ENV} get AWS_ROOT_VOLUME_SIZE)" \
		"$$(${BIN}/dotenv -f $${ENV} get AWS_DOCKER_VOLUME_SIZE)" \
		"$$(${BIN}/dotenv -f $${ENV} get AWS_REGION)" \
		"$$(${BIN}/dotenv -f $${ENV} get AWS_INSTANCE_NAME)" \
		"$$(${BIN}/dotenv -f $${ENV} get AWS_ROOT_DOMAIN)"

.PHONY: resize-volume # Resize an EBS volume on a running instance (grow only)
resize-volume:
	@INST=$$(${SELECT_INSTANCE}) && \
	ENV=${env_file} && \
	INSTANCE_NAME=$$(${BIN}/dotenv -f $${ENV} get AWS_INSTANCE_NAME) && \
	REGION=$$(${BIN}/dotenv -f $${ENV} get AWS_REGION) && \
	INSTANCE_ID=$$(aws cloudformation describe-stacks \
		--stack-name "$${INSTANCE_NAME}" \
		--region "$${REGION}" \
		--output json | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="InstanceId") | .OutputValue') && \
	readarray -t VOL_INFO < <(aws ec2 describe-volumes \
		--region "$${REGION}" \
		--filters "Name=attachment.instance-id,Values=$${INSTANCE_ID}" \
		--query 'Volumes[*].[VolumeId,Size,Attachments[0].Device]' \
		--output text | sort -k3) && \
	if [[ $${#VOL_INFO[@]} -eq 0 || -z "$${VOL_INFO[0]}" ]]; then \
		echo "## Error: No volumes found for instance $${INSTANCE_ID}." && exit 1; \
	fi && \
	VOL_LABELS=() && \
	for info in "$${VOL_INFO[@]}"; do \
		VID=$$(echo "$${info}" | awk '{print $$1}') && \
		VSIZE=$$(echo "$${info}" | awk '{print $$2}') && \
		VDEV=$$(echo "$${info}" | awk '{print $$3}') && \
		VOL_LABELS+=("$${VDEV} ($${VID}, $${VSIZE} GB)"); \
	done && \
	SELECTED=$$(${BIN}/script-wizard choose "Select volume to resize" "$${VOL_LABELS[@]}") && \
	VOL_ID=$$(echo "$${SELECTED}" | grep -oP 'vol-[a-z0-9]+') && \
	CURRENT_SIZE=$$(echo "$${SELECTED}" | grep -oP '[0-9]+ GB' | grep -oP '[0-9]+') && \
	echo "## Current size: $${CURRENT_SIZE} GB" && \
	echo "## Note: Volumes can only be grown, not shrunk." && \
	read -e -p "Enter new size in GB: " -i "$${CURRENT_SIZE}" NEW_SIZE && \
	if [[ "$${NEW_SIZE}" -le "$${CURRENT_SIZE}" ]]; then \
		echo "## Error: New size must be larger than $${CURRENT_SIZE} GB." && exit 1; \
	fi && \
	echo "## Resizing $${VOL_ID} from $${CURRENT_SIZE} GB to $${NEW_SIZE} GB..." && \
	aws ec2 modify-volume \
		--region "$${REGION}" \
		--volume-id "$${VOL_ID}" \
		--size "$${NEW_SIZE}" && \
	echo "## Volume modification initiated." && \
	echo "## The volume is resizing in the background." && \
	echo "## To expand the filesystem, SSH in and run:" && \
	echo "##   sudo resize2fs /dev/\$$(lsblk -no NAME,SERIAL | grep $${VOL_ID//-/} | awk '{print \$$1}')" && \
	echo "## Or simply: sudo resize2fs /dev/xvda1  (root) or /dev/xvdb (docker)"

.PHONY: cleanup-volumes # Delete orphaned EBS volumes (prompts for each)
cleanup-volumes:
	@INST=$$(${SELECT_INSTANCE}) && \
	ENV=${env_file} && \
	REGION=$$(${BIN}/dotenv -f $${ENV} get AWS_REGION 2>/dev/null || echo us-east-1) && \
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
