# Docker on AWS EC2

This creates an EC2 instance configured for
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech) using
AWS CloudFormation. The stack includes:

 * EC2 instance (Debian 12) with Docker pre-installed
 * Two EBS volumes (root + Docker data)
 * Elastic IP with Route53 DNS (A + wildcard records)
 * Security group with configurable firewall ports
 * IAM user + policy for Route53 ACME DNS challenges
 * Optional acme-dns deployment with DNS delegation

## Prerequisites

 * [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
   installed and configured
 * A Route53 hosted zone for your domain
 * d.rymcg.tech cloned and on your PATH (see main
   [README](../README.md))

## Login

Authenticate the AWS CLI:

```
d.rymcg.tech aws login
```

This checks if you're already authenticated. If not, it prompts you
to choose between IAM access keys or SSO.

## Configure

Create a new EC2 instance configuration:

```
d.rymcg.tech aws config
```

The wizard prompts for:

 * **Instance name** - used as the DNS subdomain prefix (e.g.
   `docker-dev` creates `docker-dev.example.com`)
 * **Root domain** - your Route53 hosted zone domain
 * **Region** - chosen from available AWS regions
 * **SSH key pair** - use an existing AWS key pair, import from
   ssh-agent, or create a new ed25519 key
 * **Instance type** - chosen from t2/t3/t3a/m6i/m7i/c6i/r6i
   families with vCPU and RAM info
 * **Volume sizes** - root and Docker data volumes (only asked on
   first config; use `resize-volume` after deployment)
 * **SSH CIDR** - restrict SSH access by IP range (`0.0.0.0/0` for
   anywhere)
 * **Open ports** - multi-select for optional services (acme-dns,
   Forgejo SSH, SFTP, etc.)

Each instance is stored as a separate `.env` file, so you can manage
multiple EC2 instances from the same workstation.

## Cost estimate

Review pricing before deploying:

```
d.rymcg.tech aws estimate
```

This queries the AWS Pricing API and shows on-demand and reserved
instance pricing, EBS storage costs, and data transfer estimates.

## Deploy

Deploy the CloudFormation stack:

```
d.rymcg.tech aws deploy
```

This automatically:

 * Resolves the Route53 hosted zone ID from the domain
 * Creates all resources via CloudFormation
 * Adds an SSH config entry to `~/.ssh/config`

After deployment, the instance is ready for Docker. The UserData
script handles formatting the Docker EBS volume, installing Docker
Engine, and adding the `admin` user to the docker group.

## Post-deployment setup

### Create Docker context

Create a Docker context pointing to the new instance:

```
docker context create docker-dev --docker "host=ssh://docker-dev"
docker context use docker-dev
```

### Verify connection

```
docker info | head -n 10
```

## Setting up acme-dns for TLS certificates

[acme-dns](https://github.com/joohoi/acme-dns) enables automated
wildcard TLS certificates via DNS-01 challenges. This is the
recommended approach for d.rymcg.tech on AWS.

### Step 1: Enable acme-dns ports during config

When running `d.rymcg.tech aws config`, select `acme-dns` in the
port selection wizard. This opens ports 53 (TCP+UDP) and 2890 (TCP),
and creates the Route53 DNS delegation records:

 * A record: `acme-dns.{instance}.{domain}` pointing to the Elastic IP
 * NS record: `acme-dns.{instance}.{domain}` delegating to itself

If you already deployed without acme-dns, re-run config and deploy
to update the stack:

```
d.rymcg.tech aws config
d.rymcg.tech aws deploy
```

### Step 2: Configure and install acme-dns

Use `d.rymcg.tech aws status` to find your public and private IP
addresses, then configure and install acme-dns:

```
d.rymcg.tech make acme-dns config
d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_SUBDOMAIN=acme-dns.docker-dev.example.com
d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_LISTEN_IP_ADDRESS=<private IP>
d.rymcg.tech make acme-dns reconfigure var=ACME_DNS_PUBLIC_IP_ADDRESS=<public IP>
d.rymcg.tech make acme-dns install
```

Wait for acme-dns to become healthy (it needs to obtain its own TLS
certificate via DNS-01, which requires the DNS delegation to have
propagated):

```
d.rymcg.tech make acme-dns status
```

### Step 3: Configure Traefik for acme-sh

```
d.rymcg.tech make traefik config
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ENABLED=true
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ACME_CA=acme-v02.api.letsencrypt.org
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ACME_DIRECTORY=/directory
d.rymcg.tech make traefik reconfigure var=TRAEFIK_ACME_SH_ACME_DNS_BASE_URL=https://acme-dns.docker-dev.example.com:2890
d.rymcg.tech make traefik reconfigure var=TRAEFIK_DOCKER_COMPOSE_PROFILES=default,error_pages,acme-sh
d.rymcg.tech make traefik reconfigure var='TRAEFIK_ACME_CERT_DOMAINS=[["docker-dev.example.com",["*.docker-dev.example.com"]]]'
d.rymcg.tech make traefik install
```

### Step 4: Register with acme-dns

```
d.rymcg.tech make traefik acme-sh-register
```

This registers an account with acme-dns and prints the CNAME records
needed for the ACME challenge.

### Step 5: Create CNAME records

Create the required CNAME records automatically:

```
d.rymcg.tech aws acme-dns-cname
```

This reads the acme-dns registration from the Traefik acme-sh
container and creates `_acme-challenge.{domain}` CNAME records in
Route53.

### Step 6: Issue certificates

After DNS propagation (usually under a minute for Route53), restart
acme-sh to trigger certificate issuance:

```
d.rymcg.tech make traefik restart service=acme-sh
```

Check the logs to verify:

```
d.rymcg.tech make traefik logs service=acme-sh
```

## Management commands

| Command | Description |
|---------|-------------|
| `d.rymcg.tech aws config` | Configure instance parameters |
| `d.rymcg.tech aws deploy` | Deploy or update the CloudFormation stack |
| `d.rymcg.tech aws status` | Show stack status, public/private IP, FQDN |
| `d.rymcg.tech aws firewall` | Show security group inbound rules |
| `d.rymcg.tech aws outputs` | Show all stack outputs |
| `d.rymcg.tech aws estimate` | Show cost estimate with pricing |
| `d.rymcg.tech aws ssh-config` | Add/update SSH config entry |
| `d.rymcg.tech aws acme-dns-cname` | Create Route53 CNAME records for ACME |
| `d.rymcg.tech aws resize-volume` | Grow an EBS volume on a running instance |
| `d.rymcg.tech aws destroy` | Tear down the CloudFormation stack |
| `d.rymcg.tech aws cleanup-volumes` | Delete orphaned EBS volumes |
| `d.rymcg.tech aws list` | List configured instances |
| `d.rymcg.tech aws login` | Authenticate the AWS CLI |

All commands support `instance=NAME` to skip the instance selection
prompt (e.g. `d.rymcg.tech aws status instance=docker-dev`).

## Instance lifecycle

 * **Resize instance** - Change the instance type in `config` and
   `deploy`. CloudFormation stops the instance, changes the type,
   and restarts it. No data loss.
 * **Resize volumes** - Use `d.rymcg.tech aws resize-volume` to grow
   EBS volumes on a running instance. Volumes can only be grown, not
   shrunk.
 * **Destroy** - `d.rymcg.tech aws destroy` deletes the stack. The
   Docker data volume is preserved (`DeleteOnTermination: false`).
   Use `cleanup-volumes` to delete orphaned volumes.
 * **Rebuild** - Delete and redeploy. The Docker data volume
   survives and can be reattached, but the root volume is
   recreated.
