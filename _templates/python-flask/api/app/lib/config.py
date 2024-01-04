import os
import logging
import werkzeug.serving

log = logging.getLogger(__name__)

APP_PREFIX = "API"
APP_ROOT = os.path.dirname(os.path.realpath(__file__))

class ConfigError(Exception):
    """A config error exception"""

def get_config(key, default=None):
    """Get config from an environment variable or use the default if not set"""
    key = f"{APP_PREFIX}_{key.upper().replace(' ','_')}"
    value = os.getenv(key, default)
    if default == None and (value == "" or value == None):
        raise ConfigError(f"Required config value is blank: {key}")
    log.debug(f"{key}={value}")
    return value


def invalid_config(variable, error_message):
    "Log error for invalid configuration and quit"
    log.error(
        f"Invalid configuration for variable {APP_PREFIX}_{variable}: {error_message}"
    )
    exit(1)


DEPLOYMENT = get_config("DEPLOYMENT", "dev")  # or "prod"

LOG_LEVEL = get_config("LOG_LEVEL", "WARNING").upper()
if LOG_LEVEL in ("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"):
    LOG_LEVEL = getattr(logging, LOG_LEVEL)
    logging.basicConfig(level=LOG_LEVEL, force=True)
else:
    invalid_config(
        "LOG_LEVEL", f"{repr(LOG_LEVEL)} - use debug, info, warning, error, or critical"
    )

DB = get_config("DB", ":memory:")
DB_POOL_SIZE = int(get_config("DB_POOL_SIZE", "5"))
DB_POOL_MAX_OVERFLOW = int(get_config("DB_POOL_MAX_OVERFLOW", "10"))
ALLOWED_EXTENSIONS = set(get_config("ALLOWED_EXTENSIONS", "png,jpg").split(","))
APP_MEDIA_FOLDER = get_config(
    "APP_MEDIA_FOLDER", os.path.join(APP_ROOT, "static/_resources")
)
UPLOAD_FOLDER = get_config(
    "UPLOAD_FOLDER", os.path.join(APP_ROOT, "static/_resources/temp")
)
RESIZE_FOLDER = get_config("RESIZE_FOLDER", os.path.join(str(APP_ROOT), str(APP_MEDIA_FOLDER)))

if DEPLOYMENT == "dev":
    HTTP_HOST = get_config("HTTP_HOST", "127.0.0.1")
    APP_SECRET_KEY = get_config("APP_SECRET_KEY", "dev")
elif DEPLOYMENT == "prod":
    HTTP_HOST = get_config("HTTP_HOST", "0.0.0.0")
    APP_SECRET_KEY = get_config("APP_SECRET_KEY")
else:
    invalid_config("DEPLOYMENT", f"{repr(DEPLOYMENT)} - use 'dev' or 'prod'")
HTTP_PORT = int(get_config("HTTP_PORT", "5001"))

## Detect if werkzeug is running the reloader thread or not:
## https://stackoverflow.com/questions/25504149/why-does-running-the-flask-dev-server-run-itself-twice/25504196#25504196
WERKZEUG_RELOADING = werkzeug.serving.is_running_from_reloader()
