from . import app
from werkzeug.middleware.proxy_fix import ProxyFix
from .lib.config import (
    logging,
    APP_PREFIX,
    HTTP_HOST,
    HTTP_PORT,
    DEPLOYMENT,
    LOG_LEVEL,
    APP_SECRET_KEY,
)

log = logging.getLogger("app")

## Configure WSGI to trust X-Forwarded-For header from Traefik Proxy
# https://flask.palletsprojects.com/en/2.2.x/deploying/proxy_fix/
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_port=1)

log.warning(
    f"{APP_PREFIX}_DEPLOYMENT={DEPLOYMENT} - Startup in {'LOCAL' if HTTP_HOST == '127.0.0.1' else 'PUBLIC'} {str(DEPLOYMENT)} mode"
)
app.run(host=HTTP_HOST, port=HTTP_PORT, debug=(DEPLOYMENT == "dev"))
