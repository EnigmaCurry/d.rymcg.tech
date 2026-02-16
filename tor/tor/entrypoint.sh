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
        f.write('HiddenServicePort 80 127.0.0.1:8000\n')
PYTHON

exec tor -f /tmp/torrc
