# aria2

This config is for [aria2 and
aria2-webui](https://github.com/ziahamza/webui-aria2) (currently
configured to use our own fork
[EnigmaCurry/webui-aria2](https://github.com/EnigmaCurry/webui-aria2)).

## Setup

### Consider installing WireGuard first

If you don't want to download files over your native ISP connection,
you may want to consider installing a [WireGuard](../wireguard) first.
Then you can tell qBittorrent to use the VPN for all of its traffic.

### Config

Run `make config` 

When asked to choose the network mode, you have two choices:

 * Use the `default` container network. This will use your native ISP
   connection.
 * Use the container network of a WireGuard instance. This will route
   all traffic through a VPN.

### Authentication and Authorization

In order to prevent unauthorized access, it is **highly recommended**
to enable sentry auth. 

See [AUTH.md](../AUTH.md) for information on adding external
authentication on top of your app.

## Deploy

Once configured, deploy it:

```
make install
```

```
make open
```

Once connected to the WebUI, you must configure it to use your Aria2 JSONRPC service.

 * Click `Settings`
 * Click `Connection Settings`
 * Enter the secret (`RPC_SECRET` from .env)
 
The rest of these settings should already be set:

 * Enter the host `aria2.example.com`
 * Enter the port `443`
 * Enter the RPC path `/jsonrc`

Click `Save Connection configuration` to save the credentials in your
browser's local storage. It should now be successfully connected to
your aria2 service.
