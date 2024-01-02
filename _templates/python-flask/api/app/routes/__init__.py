from .hello.hello_controller import hello
from flask import redirect
import logging

log = logging.getLogger(__name__)

def setup_routes(app):
    app.register_blueprint(hello, url_prefix="/hello")
    
    @app.route("/", methods=["GET"])
    def root():
        """Redirect the root page to the default blueprint"""
        return redirect("/hello")

    log.debug(app.url_map)

    @app.route("/well")
    def hello_world():
        return {"message": "yea"}
