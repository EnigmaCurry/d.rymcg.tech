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

During config you will create two accounts, identified by these environment
variables:

 * `ARCHIVEBOX_HTTP_AUTH` - this is the HTTP Basic Auth that is required to view
   the ArchiveBox page, even before logging in.
 * `ARCHIVEBOX_USERNAME` and `ARCHIVEBOX_PASSWORD` - this is the admin account
   username and password to login with the ArchiveBox application.

## Install

`make install`

## Create Admin account

`make admin`

This will create a new admin account using the `ARCHIVEBOX_USERNAME` and
`ARCHIVEBOX_PASSWORD` variables set in the config.

## API Gateway

ArchiveBox is [currently missing a REST
API](https://github.com/ArchiveBox/ArchiveBox/issues/496). This configuration
[includes an API wrapper](https://github.com/enigmacurry/archivebox-api-gateway) to
support adding URLs to archive via authenticated REST API.

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
