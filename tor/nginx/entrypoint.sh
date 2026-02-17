#!/bin/sh
set -e

python3 << 'PYTHON'
import json, os, sys

services = json.loads(os.environ.get('TOR_HIDDEN_SERVICES', '[]'))
port_base = int(os.environ.get('TOR_NGINX_PORT_BASE', '10080'))

# Collect 2-element entries [name, hostname]
proxies = []
port = port_base
for svc in services:
    if isinstance(svc, list) and len(svc) == 2:
        proxies.append((svc[0], svc[1], port))
        port += 1

if not proxies:
    print("nginx: no 2-element entries found, nothing to proxy. Exiting.")
    sys.exit(0)

with open('/tmp/nginx.conf', 'w') as f:
    f.write('pid /tmp/nginx.pid;\n')
    f.write('error_log /dev/stderr;\n')
    f.write('\n')
    f.write('events {\n')
    f.write('    worker_connections 64;\n')
    f.write('}\n')
    f.write('\n')
    f.write('http {\n')
    f.write('    access_log /dev/stdout;\n')
    f.write('    client_body_temp_path /tmp/nginx-client-body;\n')
    f.write('    proxy_temp_path /tmp/nginx-proxy;\n')
    f.write('    fastcgi_temp_path /tmp/nginx-fastcgi;\n')
    f.write('    uwsgi_temp_path /tmp/nginx-uwsgi;\n')
    f.write('    scgi_temp_path /tmp/nginx-scgi;\n')
    f.write('\n')
    for name, hostname, listen_port in proxies:
        f.write(f'    # {name} -> {hostname}\n')
        f.write(f'    server {{\n')
        f.write(f'        listen 127.0.0.1:{listen_port};\n')
        f.write(f'        location / {{\n')
        f.write(f'            proxy_pass https://127.0.0.1:443;\n')
        f.write(f'            proxy_set_header Host {hostname};\n')
        f.write(f'            proxy_ssl_server_name on;\n')
        f.write(f'            proxy_ssl_name {hostname};\n')
        f.write(f'            proxy_ssl_verify off;\n')
        f.write(f'            proxy_set_header X-Real-IP $remote_addr;\n')
        f.write(f'            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n')
        f.write(f'            proxy_set_header X-Forwarded-Proto https;\n')
        f.write(f'        }}\n')
        f.write(f'    }}\n')
        f.write('\n')
    f.write('}\n')

for name, hostname, listen_port in proxies:
    print(f"nginx: {name} listening on 127.0.0.1:{listen_port} -> https://{hostname}")
PYTHON

exec nginx -c /tmp/nginx.conf -g 'daemon off;'
