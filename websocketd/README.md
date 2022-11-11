# websocketd

[websocketd](https://github.com/joewalnes/websocketd) is a websocket and CGI
server that forwards connections to any other standard unix program (written in
any language), utilizing standard input and output.

Run `make config` and configure the following:

 * `WEBSOCKETD_TRAEFIK_HOST` - The domain name to listen on. 
 * `WEBSOCKETD_APP_PATH` - The path to listen on.
 * `WEBSOCKETD_DEV_CONSOLE` - set this to `true` or `false` to turn on or off the
   development console.

If you turned the developer console, you can run `make open` to open
it in your browser.

On the page, press the checkmark button to connect to the server. The
default server is just a counting app that will count to 10.

To implement your own websocket application, copy this entire
directory to a new name and modify the `Dockerfile` appropriately. You
can host several instances of websocketd using the same
`WEBSOCKETD_TRAEFIK_HOST` setting for each of them, but configuring
different `WEBSOCKETD_APP_PATH` settings.

