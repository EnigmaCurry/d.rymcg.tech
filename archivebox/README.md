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

You can also enter a shell on the container (`make shell`) and use the
`archivebox schedule` command manually.

Learn more about scheduling in Archivebox
[here](https://github.com/ArchiveBox/ArchiveBox/wiki/Scheduled-Archiving).
