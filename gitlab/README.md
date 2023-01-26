# Gitea

[Gitlab](https://gitlab.com/) is a git repository host, similar to GitHub, but
entirely self-hosted. More description forthcoming...

## Configuration

Copy `.env-dist` to `.env`, and edit variables accordingly. 

 * `GITLAB_TRAEFIK_HOST` to the external domain name forwarded from traefik, eg.
   `git.example.com`

Config documention forthcoming...

## Initial setup

Bring up the service with `docker-compose up -d`
Initial setup documentation forthcoming...

```
# Restart gitlab to get the config applied:
docker-compose restart
```

## Notes

Traefik listens for SSH connections on TCP port 2224 and forwards directly to
the builtin Gitlab SSH service.
