# plMail

[plMail](https://github.com/karatektus/pl_mail) is a self-hosted,
Gmail-style mail client (AGPL-3.0). It is NOT a mail server - no port 25,
no domain hosting. It syncs your existing IMAP, Gmail and Outlook
mailboxes into a PostgreSQL database and serves one web UI with
multi-account inbox, calendar, search and live updates.

## Config

```
make config
```

This asks for the domain name and lets you choose an authentication
method (HTTP basic auth, OAuth2, or mTLS). It needs no passwords: all of
plMail's secrets (including the database password) are auto-generated on
first start.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external
authentication on top of your app.

## Install

```
make install
```

## Create the first admin

Open the web interface:

```
make open
```

*IMPORTANT:* _Immediately_ create the first admin account on the
`/install` page. Until the first account exists, that page is
unauthenticated - anyone who can reach your URL becomes the admin. This
is why choosing an authentication method in `make config` matters.

Then add your mailboxes under **Settings → Mail accounts** (IMAP, Gmail
or Outlook).

## Android push without Google

plMail's Android app can deliver push notifications through
[UnifiedPush](https://www.unifiedpush.org/) instead of Google/Firebase:

1. Install the [ntfy-sh](../ntfy-sh#readme) app separately if you don't
   already run an ntfy server.
2. Install the plMail Android "no Google code" build from the
   [upstream GitHub releases](https://github.com/karatektus/pl_mail/releases).
3. In the app, pair a device under **Settings → App passwords → Pair a
   device**.

The app registers its ntfy endpoint with plMail, which just POSTs to it -
no wiring needed. If your ntfy is only reachable on your LAN or
Tailscale (not via a public URL), set `PL_MAIL_PUSH_ALLOWED_HOSTS` in
your `.env_{DOCKER_CONTEXT}_{INSTANCE}` file to your ntfy's host, since
plMail refuses push endpoints on private addresses otherwise.

## Backup

The `app_secrets` volume holds `APP_ENCRYPTION_KEY`, the key behind
every stored mailbox password and OAuth token. Losing it makes those
credentials unrecoverable (upstream's own advice: back it up separately).
Back up both the `database_data` and `app_secrets` volumes.

## Destroy

```
make destroy
```

This completely removes the container and volumes.
