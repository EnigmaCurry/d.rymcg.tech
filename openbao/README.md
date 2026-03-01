# OpenBao

[OpenBao](https://openbao.org/) is an open-source secrets management
platform (a fork of HashiCorp Vault, API-compatible with the v1 API).
It provides centralized secrets storage, dynamic credentials, and
identity-based access.

In this d.rymcg.tech deployment, OpenBao serves as:

- **SSH Certificate Authority** — issues short-lived SSH certificates
  for CI/CD pipelines (no static SSH keys).
- **AGE key store** — holds the AGE private key used to decrypt
  SOPS-encrypted configuration files.
- **AppRole auth** — machine-friendly authentication for Woodpecker CI
  agents.

## Security

Enabling mTLS (`OPENBAO_MTLS_AUTH=true`) is **HIGHLY RECOMMENDED**.
Without mTLS, the OpenBao API is exposed to unauthenticated network
access. With mTLS enabled, all clients must present a valid
certificate signed by your Step-CA before Traefik will proxy the
request to OpenBao. See [Step-CA](../step-ca#readme) for setting up
your certificate authority.

## Setup

```bash
## Configure the OpenBao env:
d.rymcg.tech make openbao config

## Install OpenBao:
d.rymcg.tech make openbao install
```

## Initialization

After first install, OpenBao must be initialized and unsealed:

```bash
## Initialize (save the unseal keys and root token securely!):
d.rymcg.tech make openbao init

## Unseal (must provide threshold number of unseal keys):
d.rymcg.tech make openbao unseal

## Check seal status:
d.rymcg.tech make openbao seal-status
```

**Important:** Save both values in a secure offline password manager
(e.g., KeePassXC):

- **Unseal key** — required every time OpenBao restarts (it always
  starts sealed). Without it, all stored secrets are permanently
  inaccessible.
- **Root token** — the initial admin credential for configuring
  OpenBao (enabling engines, creating policies, AppRoles). Can be
  revoked after setup, but is needed for all initial configuration.

## SSH Certificate Authority

Set up OpenBao as an SSH CA so CI/CD pipelines can obtain short-lived
SSH certificates:

```bash
## Enable the SSH secrets engine:
d.rymcg.tech make openbao enable-ssh-engine

## Generate the CA signing key:
d.rymcg.tech make openbao configure-ssh-ca

## Get the CA public key (add this to your servers):
d.rymcg.tech make openbao get-ssh-ca-public-key

## Create a signing role for CI/CD (15-minute TTL):
d.rymcg.tech make openbao create-ssh-role

## Verify the role configuration:
d.rymcg.tech make openbao read-ssh-role
```

### Server sshd configuration

On each target server, add the CA public key to
`/etc/ssh/trusted_user_ca_keys`:

```bash
## On the target server:
echo "<CA_PUBLIC_KEY>" > /etc/ssh/trusted_user_ca_keys

## Add to /etc/ssh/sshd_config:
echo "TrustedUserCAKeys /etc/ssh/trusted_user_ca_keys" >> /etc/ssh/sshd_config

## Restart sshd:
systemctl restart sshd
```

## AGE Key for SOPS

An AGE key is used to encrypt and decrypt SOPS configuration files.
If you don't already have one, generate it:

```bash
age-keygen
```

This outputs two lines:
- A comment with the **public key** (`age1...`) — used in your
  `.sops.yaml` to specify who can encrypt.
- The **secret key** (`AGE-SECRET-KEY-...`) — needed for decryption.

Save both in your offline password manager. Then enable the KV secrets
engine and store the secret key in OpenBao:

```bash
## Enable the KV secrets engine (if not already enabled):
d.rymcg.tech make openbao enable-kv

## Store AGE secret keys (path is required):
d.rymcg.tech make openbao put-age-key path=sops/myserver-production
d.rymcg.tech make openbao put-age-key path=sops/myserver-staging

## List all stored keys:
d.rymcg.tech make openbao list-age-keys

## Verify a specific key:
d.rymcg.tech make openbao get-age-key path=sops/myserver-production

## Delete a key:
d.rymcg.tech make openbao delete-age-key path=sops/myserver-staging
```

In your Woodpecker pipeline, set `BAO_AGE_KEY_PATH` to the path
used above (e.g., `sops/myserver-production`).

The d.rymcg.tech container entrypoint will retrieve this key
automatically when `BAO_ADDR` is set.

## AppRole Authentication

Enable AppRole auth so Woodpecker CI can authenticate:

```bash
## Enable AppRole:
d.rymcg.tech make openbao enable-approle

## Create a policy (via bao CLI):
bao policy write woodpecker-ci - <<EOF
# Read AGE key for SOPS decryption
path "secret/data/sops/age-key" {
  capabilities = ["read"]
}

# Sign SSH public keys
path "ssh-client-signer/sign/woodpecker-short-lived" {
  capabilities = ["create", "update"]
}
EOF

## Create the AppRole role:
bao write auth/approle/role/woodpecker-ci \
    token_policies="woodpecker-ci" \
    token_ttl=20m \
    token_max_ttl=30m \
    secret_id_ttl=0

## Get the role ID (store in Woodpecker secrets as BAO_ROLE_ID):
bao read auth/approle/role/woodpecker-ci/role-id

## Generate a secret ID (store in Woodpecker secrets as BAO_SECRET_ID):
bao write -f auth/approle/role/woodpecker-ci/secret-id
```

## Woodpecker CI Integration

Add these secrets to your Woodpecker CI repository:

| Secret | Description |
|--------|-------------|
| `bao_addr` | OpenBao server URL (e.g., `https://bao.example.com`) |
| `bao_role_id` | AppRole role ID |
| `bao_secret_id` | AppRole secret ID |
| `bao_cacert` | CA cert for TLS (if using private CA) |
| `bao_client_cert` | mTLS client cert (if using mTLS) |
| `bao_client_key` | mTLS client key (if using mTLS) |

See the [Woodpecker templates](../woodpecker/templates/) for example
pipeline configurations.
