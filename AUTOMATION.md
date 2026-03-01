# Automation (Deployments)

These are notes regarding the design of a secure automatic deployment
pipeline to run via Woodpecker CI.

## Architecture

### Cold-storage password manager for your secrets

Create a new offline backup password manager for your Org. You will
need to store:

 * Backup JWK token for admin access to your Step-CA certificate authority.
 * Backup SSH CA trusted by your servers.
 * Backup AGE key for SOPS secrets decryption.
 
Recommendations: KeepassXC, Vaultwarden.
 
### OpenBao secrets manager

The primary online secrets manager is OpenBao, an open source fork of
Hashicorp Vault (v1 API compatible).

 * OpenBao becomes the primary SSH Certificate Authority for your servers.
 * Your servers openssh daemon is configured to require SSH
   certificates signed by OpenBao (or your backup CA). (You may still
   also have additional backup SSH keys, but these are not to be used
   for deployments.)
 * Clients wishing to connect to a server will ask OpenBao to sign
   their SSH public key, and if authorized, they will receive a signed
   certificate with a short TTL they can use to login to the server.
 * OpenBao also holds AGE keys for decrypting SOPS encrypted config
   files stored in dev-public git repositories.

### Woodpecker CI

Woodpecker is a task runner where each job is configured via a git
repository hosted in Forgejo. The woodpecker server will read the
repositories to receive the job configuration. Jobs are triggered by
events: 

 * push: triggered when a git commit is pushed to a branch.
 * pull_request: triggered when a forgejo pull request is opened or a new commit is pushed to it.
 * pull_request_closed: triggered when a forgejo pull request is closed or merged.
 * pull_request_metadata: triggered when a forgejo pull request metadata has changed (e.g. title, body, label, milestone, ...).
 * tag: triggered when a git tag is pushed.
 * release: triggered when a forgejo release, pre-release or draft is created. (You can apply further filters using evaluate with environment variables.)
 * deployment: triggered when a deployment is created in the forgejo repository. (This event can be triggered from Woodpecker directly. GitHub also supports webhook triggers.)
 * cron: triggered when a woodpecker cron job is executed.
 * manual: triggered when a user manually triggers a pipeline.

Woodpecker terminology: 

 * Events trigger Pipelines
 * Pipelines run Workflows.
 * Workflows have Steps.
 * Steps start Docker containers to perform some work.
 * Commands are sequentially in each Step.
 * A Step (a container) is shutdown when the Commands are complete.
 
### d.rymcg.tech Docker container

d.rymcg.tech is wrapped as a Docker container that manages a single
external (SSH) Docker context. The individual .env files that make up
your deployment configs, are provided to the d.rymcg.tech in a flat
environment namespace. Each project is prefixed in the var name (e.g.
`WHOAMI_TRAEFIK_HOST`) and instances get another prefix (e.g.,
`__foo__WHOAMI_TRAEFIK_HOST`), thus the entirety of the Docker
context, and all of its containers can be expressed in the environment
of the d.rymcg.tech container.

#### SOPS config

Normally the docker container reads its configuration from the
container supplied environment (e.g, `WHOAMI_TRAEFIK_HOST` will be
restored by the entrypoint into the
`d.rymcg.tech/whoami/.env_{CONTEXT}` file). We also need to load
config from a provided SOPS encrypted archive. This is controlled by
the following env var:

 * `SOPS_CONFIG_FILE` - the path to the SOPS encrypted config file to
   merge into the deployment config, at a lower priority than
   container provided env vars.
   
So for example, if the container is provided the var
`SOPS_CONFIG_FILE=/some.sops.env` and the var
`WHOAMI_TRAEFIK_HOST=foo.example.com`, the entrypoint will first load
the SOPS config, apply all the vars from that, and then followup by
setting the regular vars from the container. (resulting in
WHOAMI_TRAEFIK_HOST=foo.example.com, regardless of the setting in the
SOPS provided config.)

#### SSH config

The container needs access to a given SSH server running Docker. It is
configured by env vars:

 * `SSH_HOST` - the hostname
 * `SSH_USER` - the SSH user
 * `SSH_PORT` - the SSH port

The SSH config is allowed to be loaded from the SOPS config if not
provided to the container.

#### OpenBao config

The container creates a fresh private SSH key on each container start.
To use the key, it must get the public key signed from OpenBao, so it
can present the certificate to the server. The container needs these
env vars to configure OpenBao:

 * `BAO_ADDR` - the URL to OpenBao (e.g. https://bao.example.com:8200)
 * `BAO_CACERT` - the CA cert to validate the TLS connection
 * `BAO_CLIENT_CERT` - the PEM cert for mTLS client
 * `BAO_CLIENT_KEY` - the PEM private key for the mTLS client
 * `BAO_NAMESPACE` - the Bao namespace
 * `BAO_AUTH_PATH` - the Bao auth path (e.g. `auth/approle`)
 * `BAO_ROLE_ID` - the Bao role
 * `BAO_SECRET_ID` - the Bao secret key
 * `BAO_SSH_MOUNT` - SSH secrets engine mount path in OpenBao where the SSH backend is enabled (default: `ssh-client-signer`)
 * `BAO_SSH_ROLE` - SSH backend role name under that mount that defines what kind of SSH credential to issue (default: `woodpecker-short-lived`)
 * `BAO_KV_MOUNT` - KV secrets engine mount path (default: `secret`)
 * `BAO_AGE_KEY_PATH` - path within KV to the AGE key (required, e.g. `sops/d2-admin/myserver-production`)
 
The `BAO_` prefixed vars are *not* allowed to be loaded by the SOPS
config, they *must* be provided to the container as env vars
(woodpecker secrets).
 
### d.rymcg.tech deployment repo

A deployment repo is separate from the d.rymcg.tech repo. A deployment
repo is a private repo that contains the woodpecker job definition as
well as a SOPS encrypted configuration. The repo configures the SSH
related config for Docker contexts as well as the entire d.rymcg.tech
config for multiple contexts.

Repo structure:

 * `.woodpecker` directory contains the woodpecker job definitions.
 * `config` directory contains SOPS encrypted config files, one per
   Docker context.

When the Woodpecker agent starts a d.rymcg.tech job, the deployment
repo is included in the container environment at `${CI_WORKSPACE}`.
The entrypoint needs to contact the OpenBao service and retrieve the
AGE decryption key to read the encrypted config. Once it has
downloaded the AGE key to a temporary file, it can set
`SOPS_AGE_KEY_FILE` with the path, and then run `d.rymcg.tech
restore-env --decrypt`, at which point it may delete the AGE key file.

Next, the entrypoint will need to acquire an SSH certificate from
OpenBao. The d.rymcg.tech will create a fresh SSH key on start, and
then send that and its authorization credentials to OpenBao, and
receive the SSH certificate. The SSH config needs to be configured to
use the certificate, user, and port, automatically whenever `ssh
${SSH_HOST}` is run during the container lifecycle.

Once the d.rymcg.tech and SSH config is restored, the container may
use normal `d.rymcg.tech` commands to perform tasks like deployments
and teardowns. These commands are expressed as commands in the
woodpecker workflow steps.
