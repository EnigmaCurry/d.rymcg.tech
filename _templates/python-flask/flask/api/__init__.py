from flask import Flask, request
from werkzeug.middleware.proxy_fix import ProxyFix
import os

from .database import db

app = Flask(__name__)

## Configure WSGI to trust X-Forwarded-For header from Traefik Proxy
# https://flask.palletsprojects.com/en/2.2.x/deploying/proxy_fix/
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_port=1)


@app.route("/")
def hello_world():
    return f"""
    <h1>Hello, World!</h1>
    <p>Project: {os.environ.get('DOCKER_PROJECT')}</p>
    <p>Instance: {os.environ.get('DOCKER_INSTANCE')}</p>
    <p>Docker Context: {os.environ.get('DOCKER_CONTEXT')}</p>
    <p>Your IP address is: {request.headers['X-Forwarded-For']}</p>
    <p>Your User Agent: {request.headers['User-Agent']}</p>
    """
