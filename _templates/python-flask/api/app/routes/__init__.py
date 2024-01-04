from .hello.hello_controller import hello
from .upload.upload_controller import upload
from flask import redirect
import logging

log = logging.getLogger(__name__)

def setup_routes(app):
    app.register_blueprint(hello, url_prefix="/hello")
    app.register_blueprint(upload, url_prefix="/upload")
    
    @app.route("/", methods=["GET"])
    def root():
        """Redirect the root page to the default blueprint"""
        return redirect("/hello")

    log.info(app.url_map)
