# ArchiveBox

[ArchiveBox](https://github.com/archivebox/archivebox) is a powerful self-hosted
website archiving tool to collect, save, and view sites that you want to
preserve offline (`.html`, `.pdf`, `.warc`).

This configuration includes HTTP Basic Authentication, effectively making the
entire site private. ArchiveBox has its own authentication system that is an
additional security layer, but only for the administrative functions. If you
wish the site to be public, comment out the `Authentication` secton of the
`docker-compose.yaml`.

## Config

`make config`

## Install

`make install`

## Create Admin account

`make admin`

### To reset the ArchiveBox password of an existing account

`make reset-password`

(To reset the HTTP Basic Authentication, re-run `make config`)
