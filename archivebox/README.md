# ArchiveBox

[ArchiveBox](https://github.com/archivebox/archivebox) is a powerful self-hosted
website archiving tool to collect, save, and view sites that you want to
preserve offline (`.html`, `.pdf`, `.warc`).

If you are new to d.rymcg.tech, make sure to read the main
[README.md](../README.md) first.

## Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

## Config

`make config`

This will create the environment variables `ARCHIVEBOX_USERNAME`,
`ARCHIVEBOX_EMAIL`, and `ARCHIVEBOX_PASSWORD`, which are used to create an
initial admin account. You must create the admin account after the app is
installed before you will be able to use the app. 

## Install

`make install`

### Create Admin account

You must create an initial admin account before you can use Archivebox:

`make admin`

This will create an admin account using the `ARCHIVEBOX_USERNAME`,
`ARCHIVEBOX_EMAIL`, and `ARCHIVEBOX_PASSWORD` variables set in the configuration
file `.env_{INSTANCE}`. You can change the login name, email, and password of
the admin account in the UI.

## Scheduling Snapshots

Archivebox can automatically snapshot URLs on a schedule, but you can only
manage those schedules via the Archivebox CLI. You can use these makefile targets
to manage most of the scheduling functions.
- `make schedule-add`: Add a new scheduled ArchiveBox crawl
- `make schedule-clear`: Disable all ArchiveBox scheduled crawls
- `make schedule-help`: Show help for scheduling commands
- `make schedule-overwrite`: Re-archive any URLs that have been previously
  archived, overwriting existing Snapshots
- `make schedule-show`: Print a list of currently active ArchiveBox scheduled crawls
- `make schedule-update`: Re-pull any URLs that have been previously added, as
  needed to fill missing archive results

Scheduled crawls are stored in the ArchiveBox database and are processed
automatically by the archivebox server while it is running (no cron jobs
involved).

You can also enter a shell on the container (`make shell` and select
"archivebox") and use the `archivebox schedule` command manually:

Learn more about scheduling in Archivebox
[here](https://github.com/ArchiveBox/ArchiveBox/wiki/Scheduled-Archiving).

## API Gateway

ArchiveBox is [currently missing a REST
API](https://github.com/ArchiveBox/ArchiveBox/issues/496). This configuration
[includes an API wrapper](https://github.com/enigmacurry/archivebox-api-gateway) to
support adding URLs to archive via authenticated REST API.

> [!WARNING]
> The API gateway was written against the ArchiveBox 0.7 web UI. ArchiveBox
> 0.9.x rewrote its web UI and API, so the gateway may no longer work until
> the [archivebox-api-gateway](https://github.com/enigmacurry/archivebox-api-gateway)
> repository is updated for 0.9.x.

Make sure to configure the following variables (`make config` does this for
you):

 * `SECRET_KEY` - this is used to hash URLs and provide access control (users
   must pass the hash back in the request, in order to view the archived page).
 * `ARCHIVEBOX_USERNAME` and `ARCHIVEBOX_PASSWORD` this is the admin account
   username and password for ArchiveBox. The API gateway will login to
   ArchiveBox via these credentials. These credentials in the config must be
   kept up-to-date should you change the ArchiveBox username or password.

The API gateway can be accessed via
`https://${ARCHIVEBOX_TRAEFIK_HOST}/api-gateway/` URL. An example form that
submits a URL is provided, or you can HTTP POST to
`https://${ARCHIVEBOX_TRAEFIK_HOST}/api-gateway/page`. This will return a URL with an embedded page hash key of `URL + SECRET_KEY`

Anonymous (public) access to
`https://${ARCHIVEBOX_TRAEFIK_HOST}/api-gateway/page` is allowed for `GET`
requests only. To retrieve an archived page you must pass the page key hash of
the `URL + SECRET_KEY`. This will ensure only people who have the full link may
access the page.
