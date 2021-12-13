# CryptPad

[CryptPad](https://cryptpad.fr/) is an encrypted, open source collaboration
suite.

CryptPad is designed to serve its content over two domains. Account passwords
and cryptographic content is handled on the 'main' domain, while the user
interface is loaded from a 'sandbox' domain.

Copy `.env-dist` to `.env`, and edit these variables: 

 * `CPAD_MAIN_DOMAIN` the external domain name to forward from traefik for
 the main site.
 * `CPAD_SANDBOX_DOMAIN` the external domain name to forward from traefik for
 sandboxed content.

Cryptpad requires a configuration file (config.js) :

 * Copy `config.example.js` to `config.js` in the same directory.
 * Edit the `httpUnsafeOrigin` field, and put the same value as you used for
   `CPAD_MAIN_DOMAIN`, for example `https://pad.example.com`.
 * Edit the `httpSafeOrigin` field, and put the same value as you used for
   `CPAD_SANDBOX_DOMAIN`, for example `https://pad.box.example.com`.
 * Editing the rest of the fields is optional, you may wish to change
   `adminEmail` if you want the in-app support links to work.

You must start cryptpad initially using the default config, then you can copy
your config into the container volume, and then restart. Once restarted, the
container will be running with your edited config.
 
 * Run `docker-compose up -d` to start the container.
 * Copy the config: `docker cp config.js cryptpad:/cryptpad/config/config.js`
 * Run `docker-compose restart`
 * You must re-do this process anytime you change `config.js`.
 
Visit the main domain in your browser, and sign up for an account. Go to the
user settings page, and find your public signing key (example:
`[cryptpad-user1@my.awesome.website/YZgXQxKR0Rcb6r6CmxHPdAGLVludrAF2lEnkbx1vVOo=]`)
 
Edit `config.js` again, and uncomment the `adminKeys` section and add your user
key (and remove the example key). Copy the config.js to the volume again using
`docker cp` and restart the container again. Now your user can access the
(limited) adminstration page to edit some addtional settings using the web app.
