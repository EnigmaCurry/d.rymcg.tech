# d.rymcg.tech

[![License: MIT](_meta/img/license-MIT.svg)](https://github.com/EnigmaCurry/d.rymcg.tech/blob/master/LICENSE.txt)
[![Chat on Matrix](_meta/img/matrix-badge.svg)](https://matrix.to/#/#d.rymcg.tech:enigmacurry.com)

d.rymcg.tech is a collection of open-source Docker Compose projects
and command line tools to manage your remote Docker services from your
workstation.

## Features

 * Docker can be deployed anywhere, e.g.:
 
   * A public server in the cloud (DigitalOcean droplet, AWS EC2, etc.)
   * A public server running at home via direct port forwarding from your
     internet router.
   * A private server (at home or in the cloud) that requires a VPN to connect
     (WireGuard).
   * A public server (at home and/or roaming), without direct port
     forwarding, but accessible with the help of a public (cloud)
     sentry VPN (WireGuard).

 * d.rymcg.tech has a clean separation for the roles of workstation
   and server:
   
   * All source files and CLI tools live on your workstation. All
     administration is performed on your workstation. You should never
     need to directly SSH into the server's shell.
   * The server's only job is to build and run the Docker containers
     that your workstation tells it how to.

 * All configuration is sourced from environment variables written in
   `.env` files on your workstation. Each service deployment has a
   separate `.env_{CONTEXT}_{INSTANCE}` file (per project directory,
   per docker context, per service instance).

 * Every sub-project has a `Makefile`, with common targets, to wrap
   all Docker commands and administrative functions for that project,
   e.g.:
   
   * `make config` is a wizard to help you configure the `.env` file.
   * `make install` installs the configured application on the server.
   * `make open` opens the installed application in your workstation's
     web browser.
   * `make uninstall` tears down, and removes, a project's containers,
     but keep the data volumes.
   * `make destroy` is like uninstall, but will delete the data
     volumes as well.
   * `make readme` opens the current project's README.md in your
     workstation's web browser.
   * Note: `make` requires that your current working directory is
     where the Makefile is, so you must `cd` into the proper
     sub-directory before running `make`.
   
 * This project provides a command line alternative to `make` named
   `d.rymcg.tech` (or `d` alias) that provides a global command
   structure and re-wraps all of the sub-project `make` commands, but
   unlike `make`, it works from any directory (e.g., `d make whoami
   config`, `d make whoami install` ...)
   
 * This repository only offers services that have open source
   licenses. You may create your own projects in external git
   repositories, license them however you wish, and still benefit from
   the same command line tooling.

 * [Traefik](traefik#traefik) is deployed as the front door proxy for
   all of your services (HTTP / TCP / UDP). Traefik provides TLS
   termination and sentry authentication/authorization middleware
   (mTLS, OAuth, HTTP Basic, IP source range). Applications define
   their own routes (domain names, paths, etc.), and other Traefik
   middleware config, via container labels.

 * d.rymcg.tech focuses on the needs of the full-stack self-hoster.
     You can deploy your own Certficate Authority and DNS (delegate)
   server for the automatic creation of (wildcard) TLS certificates
   with
   [Step-CA](step-ca#step-ca)
   and
   [acme-dns](acme-dns#acme-dns).
   (Be your own Let's Encrypt alternative.)

## Documentation

The documentation for this project is spread amongst several Markdown
files, according to project and/or topic.

Follow these topical guides to get started:

 * Create your workstation environment:
 
   * [WORKSTATION_LINUX.md](WORKSTATION_LINUX.md) - Setup your workstation on Linux.
   * [WORKSTATION_WSL.md](WORKSTATION_WSL.md) - Setup your workstation on Windows (WSL).
 
* Create a Docker server and configure the firewall:
 
   * [DOCKER.md](DOCKER.md) - Install Docker Engine on bare metal, VM,
     or cloud server.

* Install applications:

   * [TOUR.md](TOUR.md) - follow this tour guide to install your first
     set of services.

### Extra reading

 * [SECURITY.md](SECURITY.md) - how to secure a Docker server.
 * [MAKEFILE_OPS.md](MAKEFILE_OPS.md) - how to write Makefiles.
 * [RCLONE.md](RCLONE.md) - create Docker volumes on top of
   remote/cloud storage (S3, SFTP, Dropbox, etc.)
 * [LICENSE.txt](LICENSE.txt) - the license for this project.
 
## Services

Each of the sub-projects in this repository have their own `README.md`
in their respective sub-directory.

Install these services first:

* [Acme-DNS](acme-dns#readme) - a DNS server for ACME challenges (TLS
  certificate creation)
* [Traefik](traefik#readme) - HTTP / TLS / TCP / UDP reverse proxy
* [Whoami](whoami#readme) - HTTP test service

Install these core services as needed:

* [Forgejo](forgejo#readme)
  * A git host (fork of Gitea/Gogs, which is similar to self-hosted
    GitHub).
  * This can act as an OAuth2 identity service, which supports 2FA
    including hardware tokens, and can provide authentication to all
    of your other services.
  * A single instance should be used for your entire organization, so
    you don't need to install this on every server.
* [Traefik-forward-auth](traefik-forward-auth#readme)
  * Traefik OAuth2 authentication middleware.
  * Required if you want OAuth2 authentication. You'll combine this
    with your Forgejo instance (or another external Oauth provider) to
    add authentication to any of your apps.
  * This is a Traefik middleware, and must be installed on every
    server that you want to enforce OAuth on (but they could all share
    a single external Forgejo instance).
* [Step-CA](step-ca) 
  * A self-hosted Certificate Authority (CA).
  * Provides ACME services for automatic TLS certficate creation.
  * Issue client certificates for Mutual TLS (mTLS).
  * A single instance should be used for your entire organization, so
    you don't need to install this on every server.
* [Postfix-Relay](postfix-relay#readme)
  * A simple email forwarding service (SMTP) which can be used by any
    other container that needs to send email.
  * This is a private Docker service, so you must install it on each
    server you want to send mail from.

Install these applications at your preference:

* [13ft](thirteenft#readme) - a tool to block ads and bypass paywalls
* [Actual](actual#readme) - a personal finance tool
* [ArchiveBox](archivebox#readme) - a website archiving tool
* [Audiobookshelf](audiobookshelf#readme) - an audiobook and podcast server
* [Autoheal](autoheal#readme) - a Docker container healthcheck monitor with auto-restart service
* [Backrest](backrest#readme) - a backup tool based on restic
* [Backup-Volume](backup-volume#readme) - a Docker volume backup tool
* [Baikal](baikal#readme) - a lightweight CalDAV+CardDAV server
* [Caddy](caddy#readme) - an HTTP server with automatic TLS (passthrough)
* [CalcPad](calcpad#readme) - a different take on the caculator
* [Calibre](calibre#readme) - an ebook manager
* [ComfyUI](comfyui#readme) - an AI image/video/audio generator
* [Commentario](commentario#readme) - a website comment service
* [Copyparty](copyparty#readme) - a file server webapp for multiple users and volumes
* [Coturn](coturn#readme) - a TURN relay server for NAT traversal
* [Datetime](datetime#readme) - a time viewing and conversion tool
* [DOH-server](doh-server#readme) - a DNS-over-HTTPs proxy resolver
* [DrawIO](drawio#readme) - a diagram / whiteboard editor tool
* [Ejabberd](ejabberd#readme) - an XMPP (Jabber) server
* [Filebrowser](filebrowser#readme) - a web based file manager
* [FreshRSS](freshrss#readme) - an RSS reader / proxy
* [Glances](glances#readme) - a cross-platform system monitoring tool
* [Gradio](gradio#readme) - a configurable web interface for machine learning 
* [Grocy](grocy#readme) - a grocery & household management/chore solution
* [Homepage](homepage#readme) - a dashboard for all your apps
* [Icecast](icecast#readme) - a SHOUTcast compatible streaming multimedia server
* [Immich](immich#readme) - a photo gallery
* [Invidious](invidious#readme) - a Youtube proxy
* [InvokeAI](invokeai#readme) - an AI image generator
* [Iperf](iperf#readme) - a bandwidth speed testing service
* [IT-Tools](it-tools#readme) - a collection of useful tools for developers and people working in IT
* [Jitsi Meet](jitsi-meet#readme) - a video conferencing and screencasting service
* [Jupyterlab](jupyterlab#readme) - a web based code editing environment / reproducible research tool
* [Kokoro Web](kokoro#readme) - a browser-based AI voice generator that lets you create natural-sounding voices
* [Lemmy](lemmy#readme) - a link aggregator and forum for the fediverse
* [Matterbridge](matterbridge#readme) - a chat room bridge (IRC, Matrix, XMPP, etc)
* [Maubot](maubot#readme) - a matrix Bot
* [Minio](minio#readme) - an S3 storage server
* [Mopidy](mopidy#readme) - a streaming music server built with MPD and Snapcast
* [Mosquitto](mosquitto#readme) - an MQTT server
* [Nextcloud](nextcloud#readme) - a collaborative file server
* [Nginx](nginx#readme) - a webserver configured with fast-cgi support for PHP scripts
* [Node-RED](nodered#readme) - a graphical event pipeline editor
* [Ntfy-sh](ntfy-sh#readme) - a simple HTTP-based pub-sub notification service
* [Open WebUI](openwebui#readme) - a self-hosted AI platform designed to operate entirely offline
* [Pairdrop](pairdrop#readme) - a webapp (PWA) to send files and messages peer to peer
* [Peertube](peertube#readme) - a decentralized and federated video platform
* [Photoprism](photoprism#readme) - a photo gallery and manager
* [Piwigo](piwigo#readme) - a photo gallery and manager
* [Plausible](plausible#readme) - a privacy friendly web visitor analytics engine
* [PostgreSQL](postgresql#readme) - a database server configured with mutual TLS authentication for public networks
* [PrivateBin](privatebin#readme) - a minimal, encrypted, zero-knowledge, pastebin
* [Prometheus](prometheus#readme) - a systems monitoring and alerting toolkit (+ node-exporter + cAdvisor + Grafana)
* [QBittorrent-Wireguard](qbittorrent-wireguard#readme) - a Bittorrent (libtorrent v2) client with a combined VPN client
* [Redbean](redbean#readme) - a small website server bundled in a single executable zip file
* [Redmine](redmine#readme) - a flexible project management web application
* [Registry](registry#readme) an OCI container registry
* [S3-proxy](s3-proxy#readme) - an HTTP directory index for S3 backend
* [SearXNG](searxng#readme) - a privacy-respecting, hackable metasearch engine
* [SFTP](sftp#readme) - a secure file server
* [Shaarli](shaarli#readme) - a bookmark manager
* [Smokeping](smokeping#readme) - a network latency measurement tool
* [Speedtest Tracker](speedtest-tracker#readme) - a network privacyerformance monitor
* [Syncthing](syncthing#readme) - a multi-device file synchronization tool
* [Sysbox-Systemd](sysbox-systemd#readme) - a traditional service manager for Linux running in an unprivileged container via sysbox-runc
* [Tesseract](tesseract#readme) - a front-end for Lemmy instances
* [Thttpd](thttpd#readme) - a tiny/turbo/throttling HTTP server for serving static files
* [Tiny Tiny RSS](ttrss#readme) - an RSS reader / proxy
* [TriliumNext Notes](triliumnext-notes#readme) - a note-taking/knowledge base application
* [Vaultwarden](vaultwarden#readme) - a bitwarden compatible password manager written in Rust (formerly bitwarden_rs)
* [Websocketd](websocketd#readme) - a websocket / CGI server
* [WireGuard-Gateway](wireguard-gateway) - a VPN client config that acts as a gateway node for your LAN.
* [Wordpress](wordpress#readme) - a ubiquitous blogging / CMS platform, with a plugin to build a static HTML site snapshot
* [XBrowserSync](xbs#readme) - a bookmark manager
* [YOURLS](yourls#readme) - a URL shortener
