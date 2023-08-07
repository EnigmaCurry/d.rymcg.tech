/// Run a restart script when receiving a webhook
/// Thanks to this template: https://github.com/AndrewShpagin/push_restart_webhook
/// Github webhook docs: https://docs.github.com/en/webhooks-and-events/webhooks/securing-your-webhooks

const http = require('http');
const child_process  = require('child_process');
const ip = require("ip");
const express = require('express');
const crypto = require('crypto');
const bodyParser = require('body-parser')

const get_config = function(var_name, default_value) {
    let value = process.env[var_name] != undefined ? process.env[var_name] : default_value;
    if (value === undefined) {
        console.error(`No value supplied for environment variable ${var_name} and no default was provided.`)
        process.exit(1)
    }
    return value;
}

const PORT = get_config("RELOAD_WEBHOOK_PORT", 8070)
const PATH_PREFIX = get_config("RELOAD_WEBHOOK_PATH_PREFIX", "")
const HMAC_SECRET = get_config("RELOAD_WEBHOOK_HMAC_SECRET")

const verify_signature = (req) => {
    if (req.body === undefined || req.body === {}) {
        return false;
    } else {
        const signature = crypto
              .createHmac("sha256", HMAC_SECRET)
              .update(JSON.stringify(req.body))
              .digest("hex")
        return `sha256=${signature}` === req.get("x-hub-signature-256")
    }
}

const app = express();
app.use(bodyParser.json())
const server = http.createServer(app);

let last_log = "Last log is empty."

app.post(`${PATH_PREFIX}/restart`, (req, res, next) => {
    if (verify_signature(req)) {
        console.log(`Request body: ${JSON.stringify(req.body)}`)
        console.log("Restarting ...")
        child_process.exec("sh restart.sh", {}, (code, stdout, stderr) => {
            last_log = code ? stderr : stdout
        });
        res.writeHead(200)
        res.end("200 OK: Restart request received.\n")
        console.log("200 OK: Restart request received.")
    } else {
        res.writeHead(401)
        res.end("401 Unauthorized: invalid request signature.\n")
        console.error("401 Unauthorized: invalid request signature")
    }
})


try{
    server.listen(PORT);
    console.log("")
    console.log(`Reloader webhook started at:\nhttp://${ip.address()}:${PORT}${PATH_PREFIX}/restart`);
} catch(err){
    console.log(`Unable to start the webhook server, probably the port ${PORT} is busy.`);
}
