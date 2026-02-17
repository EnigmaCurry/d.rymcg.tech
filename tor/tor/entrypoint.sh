#!/bin/sh
set -e

python3 << 'PYTHON'
import json, os

services = json.loads(os.environ.get('TOR_HIDDEN_SERVICES', '[]'))

with open('/tmp/torrc', 'w') as f:
    f.write('SocksPort 0\n')
    f.write('Log notice stdout\n')
    for svc in services:
        if isinstance(svc, str):
            # HTTP service: port 80 -> web_plain entrypoint (8000)
            f.write('HiddenServiceDir /var/lib/tor/' + svc + '\n')
            f.write('HiddenServicePort 80 127.0.0.1:8000\n')
        else:
            # TCP service: tor_port -> local_port on localhost
            f.write('HiddenServiceDir /var/lib/tor/' + svc[0] + '\n')
            f.write('HiddenServicePort {} 127.0.0.1:{}\n'.format(svc[1], svc[2]))
PYTHON

exec tor -f /tmp/torrc
