# Gitea

[Gitea](https://gitea.com/) is a git repository host as well as an OAuth
server. You can use it to store your git repositories, but more importantly
for our purposes, it can integrate with
[thomseddon/traefik-forward-auth](https://github.com/thomseddon/traefik-forward-auth)
(TODO) so that it can act as an authentication middleware for Traefik, ensuring
that only valid accounts can access protected containers. Traefik will pass the
`X-Forwarded-User` header containing the authenticated user, so that the
container itself can do per-user authorization if needed.

Copy `.env-dist` to `.env`, and edit variables accordingly. 

 * `GITEA_TRAEFIK_HOST` to the external domain name forwarded from traefik, eg.
   `git.example.com`

Bring up the service with `docker-compose up -d`, then immediately open the
domain in your browser to finish the setup procedure. Most of the data in the
form should be pre-filled and correct, but you still need to setup an
adminstrator account and password (at the very bottom, expand the section.)

Traefik listens for SSH connections on TCP port 2222 and forwards directly to
the builtin Gitea SSH service.
