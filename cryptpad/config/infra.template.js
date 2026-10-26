// SPDX-FileCopyrightText: 2026 XWiki CryptPad Team <contact@cryptpad.org> and contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

/*  This is the template for the CryptPad 'infra' configuration, which the
 *  one-shot config service renders to /cryptpad/config/infra.js on every
 *  start. Since CryptPad 2026.10.0 the server configuration is split in
 *  two: config.js holds the instance settings (storage, logging, paths)
 *  and infra.js holds the network topology: the public (reverse-proxied)
 *  HTTP endpoint and the internal front/core/storage node layout.
 *
 *  The rewritten server runs all its node types inside our single
 *  container, so the topology below is the stock single-host layout from
 *  config/infra.example.js in the cryptpad/cryptpad image. The public
 *  values come from our environment:
 *
 *    CPAD_MAIN_DOMAIN     full origin clients use (https://...)
 *    CPAD_SANDBOX_DOMAIN  full sandbox origin (https://...)
 */
module.exports = {
    "public": {
        // Public URL of the instance (used for Content-Security-Policy)
        origin: '${CPAD_MAIN_DOMAIN}',
        // Sandbox URL of the instance
        sandboxOrigin: '${CPAD_SANDBOX_DOMAIN}',
        // The image's bundled config is patched to listen on localhost
        // only; we serve through Traefik, so listen on all interfaces:
        httpHost: '0.0.0.0',
        // Single public port: since 2026.10.0 HTTP and websockets share it
        httpPort: 3000,
        // (Optional) API server URL if hosted on a different domain (ws and http)
        //externalWebsocketURL: undefined,
        //fileHost: undefined,
        // (Optional) httpServerId only useful in multi-server cases
        //httpServerId: "",
    },
    // Configure the topology here. Add or remove nodes on each level
    // depending on your instance usage.
    // "host" and "port" correspond to the node's websocket channel
    "front": [
        {
            host: "localhost",
            port: 3010, // Public http and websocket port
        },
        {
            host: "localhost",
            port: 3011,
        }
    ],
    "core": [
        {
            host: "localhost",
            port: 3020, // Internal websocket between all nodes
        },
        {
            host: "localhost",
            port: 3021,
        }
    ],
    "storage": [
        {
            host: "localhost",
            port: 3030, // Public port to serve "blob", "block", etc.
            wsPort: 3040, // Internal websocket between storage nodes
        },
        {
            host: "localhost",
            port: 3031,
            wsPort: 3041,
        }
    ]
};
