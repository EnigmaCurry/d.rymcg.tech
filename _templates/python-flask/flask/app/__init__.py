from flask import Flask, request
from werkzeug.middleware.proxy_fix import ProxyFix
from flask import render_template
import os

from .database import db

app = Flask(__name__)

## Configure WSGI to trust X-Forwarded-For header from Traefik Proxy
# https://flask.palletsprojects.com/en/2.2.x/deploying/proxy_fix/
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_port=1)


@app.route("/add", methods=("POST",))
def add():
    with db.cursor() as cur:
        cur.execute("SELECT 2 + 2")
        return f"2 + 2 = {cur.fetchone()}"


@app.route("/")
def hello_world():
    with db.cursor() as cur:
        cur.execute("SELECT 2 + 2")
        answer = cur.fetchone()[0]
    return render_template(
        "index.html",
        DOCKER_PROJECT=os.environ["DOCKER_PROJECT"],
        DOCKER_INSTANCE=os.environ["DOCKER_INSTANCE"],
        DOCKER_CONTEXT=os.environ["DOCKER_CONTEXT"],
        request=request,
        answer=answer,
    )
