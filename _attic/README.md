# Attic

The apps listed below are decommissioned and no longer supported. Their files
were removed from this directory because their stale dependencies kept
setting off Dependabot alerts (see
[#699](https://github.com/EnigmaCurry/d.rymcg.tech/issues/699)).

The last version of every attic app is still in git history, at commit
[39ae18a8](https://github.com/EnigmaCurry/d.rymcg.tech/tree/39ae18a8bf65a825fd95670770bf9f26a6dad2bd/_attic).
With some love and care, any of them could be restored and moved back into the
root directory:

```
git checkout 39ae18a8bf65a825fd95670770bf9f26a6dad2bd -- _attic/<app>
```

Caveat Emptor!

* [Mailu](https://github.com/EnigmaCurry/d.rymcg.tech/tree/39ae18a8bf65a825fd95670770bf9f26a6dad2bd/_attic/mailu) - an email service suite. Run a private mail server connected to a public relay host.
* [transmission-wireguard](https://github.com/EnigmaCurry/d.rymcg.tech/tree/39ae18a8bf65a825fd95670770bf9f26a6dad2bd/_attic/transmission-wireguard) - an older but very popular Bittorrent (v1) client with a combined VPN client
* [TiddlyWiki (WebDAV version)](https://github.com/EnigmaCurry/d.rymcg.tech/tree/39ae18a8bf65a825fd95670770bf9f26a6dad2bd/_attic/tiddlywiki-webdav#readme) - a personal wiki stored in a single static HTML file
* [TiddlyWiki (NodeJS version)](https://github.com/EnigmaCurry/d.rymcg.tech/tree/39ae18a8bf65a825fd95670770bf9f26a6dad2bd/_attic/tiddlywiki-nodejs#readme) - Advanced server edition of TiddlyWiki with image CDN
* [Tiny Tiny RSS](https://github.com/EnigmaCurry/d.rymcg.tech/tree/39ae18a8bf65a825fd95670770bf9f26a6dad2bd/_attic/ttrss#readme) - an RSS reader / proxy
* [Wireguard layer4 proxy](https://github.com/EnigmaCurry/d.rymcg.tech/tree/39ae18a8bf65a825fd95670770bf9f26a6dad2bd/_attic/wireguard#readme) - This old wireguard config has been usurped by the traefik config.
* [_docker_vm](https://github.com/EnigmaCurry/d.rymcg.tech/tree/39ae18a8bf65a825fd95670770bf9f26a6dad2bd/_attic/_docker_vm) - Docker VM management scripts, replaced by [nixos-vm-template](https://github.com/EnigmaCurry/nixos-vm-template).
* [draw.io](https://github.com/EnigmaCurry/d.rymcg.tech/tree/39ae18a8bf65a825fd95670770bf9f26a6dad2bd/_attic/drawio#readme) - diagramming app, deprecated because it is not really open source.
* [Filestash](https://github.com/EnigmaCurry/d.rymcg.tech/tree/39ae18a8bf65a825fd95670770bf9f26a6dad2bd/_attic/filestash#readme) - a web-based file manager for many storage backends.
* [Gitea](https://github.com/EnigmaCurry/d.rymcg.tech/tree/39ae18a8bf65a825fd95670770bf9f26a6dad2bd/_attic/gitea#readme) - git forge, deprecated in favor of [Forgejo](../forgejo#readme).
* [Larynx](https://github.com/EnigmaCurry/d.rymcg.tech/tree/39ae18a8bf65a825fd95670770bf9f26a6dad2bd/_attic/larynx#readme) - text-to-speech engine from the Rhasspy project.
