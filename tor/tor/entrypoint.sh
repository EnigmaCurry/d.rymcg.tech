#!/bin/sh
set -e

python3 << 'PYTHON'
import json, os

services = json.loads(os.environ.get('TOR_HIDDEN_SERVICES', '[]'))

with open('/tmp/torrc', 'w') as f:
    f.write('SocksPort 0\n')
    f.write('Log notice stdout\n')
    for svc in services:
        name = svc[0]
        service_dir = '/var/lib/tor/' + name
        f.write('HiddenServiceDir ' + service_dir + '\n')
        if len(svc) == 2:
            # HTTP service: port 80 -> web_plain entrypoint (8000)
            f.write('HiddenServicePort 80 127.0.0.1:8000\n')
        elif len(svc) == 3:
            # TCP service: tor_port -> traefik_port on localhost
            f.write('HiddenServicePort {} 127.0.0.1:{}\n'.format(svc[1], svc[2]))
PYTHON

exec tor -f /tmp/torrc
