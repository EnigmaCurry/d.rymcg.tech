# Woodpecker

[Woodpecker CI](https://woodpecker-ci.org/) is a community fork of Drone, a
container-native continuous integration engine. Woodpecker uses
[Forgejo](../forgejo) as its forge backend for OAuth authentication and
repository integration.

This project deploys two components via Docker Compose profiles:

 * **server** - the web UI and API, exposed via Traefik
 * **agent** - connects to the server over gRPC and runs CI pipelines using
   Docker

The server and agent can run on the same host or on separate Docker contexts.

## Configuration

```
make config
```

During configuration you will select which profile(s) to enable (`server`,
`agent`, or both).

### Forgejo OAuth setup

Before configuring Woodpecker, create an OAuth2 application in Forgejo:

 1. In Forgejo, go to **User Settings > Applications**
    (`https://git.example.com/user/settings/applications`).
 2. Create a new OAuth2 application:
    * **Application Name:** `Woodpecker`
    * **Redirect URI:** `https://woodpecker.example.com/authorize`
      (substitute your actual `WOODPECKER_TRAEFIK_HOST` domain)
 3. Copy the **Client ID** and **Client Secret**.

Set the following variables in your `.env_${DOCKER_CONTEXT}_default` file:

 * `WOODPECKER_FORGEJO=true`
 * `WOODPECKER_FORGEJO_URL` - the URL of your Forgejo instance, eg.
   `https://git.example.com`
 * `WOODPECKER_FORGEJO_CLIENT` - the OAuth2 Client ID from Forgejo
 * `WOODPECKER_FORGEJO_SECRET` - the OAuth2 Client Secret from Forgejo
 * `WOODPECKER_ADMIN` - comma-separated list of Forgejo usernames that
   should have admin access in Woodpecker

### Agent configuration

The agent authenticates to the server using a shared secret
(`WOODPECKER_AGENT_SECRET`) which is auto-generated during `make config`.
The agent connects to the server's gRPC endpoint
(`WOODPECKER_GRPC_HOST`) over TLS.

If you run the agent on a separate host from the server, copy the
`WOODPECKER_AGENT_SECRET` value from the server's env file to the agent's
env file, and ensure `WOODPECKER_GRPC_HOST` and `WOODPECKER_GRPC_SECURE`
are set correctly.

## Install

```
make install
```

Open the web UI:

```
make open
```

Log in with your Forgejo account. Repositories from Forgejo will be
available for activation in the Woodpecker dashboard.
