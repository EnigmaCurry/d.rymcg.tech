# xBrowserSync

[xBrowserSync](http://www.xbrowsersync.org) is a free tool for syncing
browser data between different browsers and devices, built for privacy
and anonymity.

## Config

```
make config
```

Optional: copy xbs/api/settings-dist.json to xbs/api/settings.json and edit to
include any custom settings you wish to run on your service. Important:
the db.host value should match the container name of the "db" service in
xbs/docker-compose.yml.

## Install

```
make install
```


## Open in your browser

```
make open
```
