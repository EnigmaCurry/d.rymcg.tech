# websocketd

[websocketd](https://github.com/joewalnes/websocketd) is a websocket and CGI
server that forwards connections to any other standard unix program (written in
any language), utilizing standard input and output.

Copy `.env-dist` to `.env` and set the variables:

 * `SOCKET_TRAEFIK_HOST` - The domain name to listen on. 
 * `APP_PATH` - The path to listen on.
 * `DEV_CONSOLE` - set this to `true` or `false` to turn on or off the
   development console.
 
With `DEV_CONSOLE` set to true, open your browser to the `SOCKET_TRAEFIK_HOST` +
`APP_PATH` (eg. `https://socket.example.com/app`)

Press the checkmark button to connect to the server. The default server is just
a counting app that will count to 10.

To implement your own websocket application, copy this entire directory and
modify `Dockerfile` appropriately.

