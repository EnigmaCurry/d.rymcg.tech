from .hello.hello_controller import hello

def setup_routes(app):
    app.register_blueprint(hello, url_prefix="/hello")
