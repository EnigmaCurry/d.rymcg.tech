import sys
import os
import logging

log = logging.getLogger(__name__)

class ConfigError(Exception):
    """A config error exception"""

APP_PREFIX = "APP"
APP_ROOT = os.path.dirname(os.path.realpath(__file__))
    
def get_config(key, default=None):
    """Get config from an environment variable or use the default if not set"""
    key = f"{APP_PREFIX}_{key.upper().replace(' ','_')}"
    value = os.getenv(key, default)
    if default == None and (value == "" or value == None):
        raise ConfigError(f"Required config value is blank: {key}")
    log.debug(f"{key}={value}")
    return value

def get_logger(name):
    log = logging.getLogger(name)
    return log

def invalid_config(variable, error_message):
    "Log error for invalid configuration and quit"
    log.error(
        f"Invalid configuration for variable {APP_PREFIX}_{variable}: {error_message}"
    )
    exit(1)
    
LOG_LEVEL = get_config("LOG_LEVEL", "WARNING").upper()
if LOG_LEVEL in ("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"):
    LOG_LEVEL = getattr(logging, LOG_LEVEL)
    logging.basicConfig(level=LOG_LEVEL, force=True)
    log.info(f"Logging level set: {LOG_LEVEL}")
else:
    invalid_config(
        "LOG_LEVEL", f"{repr(LOG_LEVEL)} - use debug, info, warning, error, or critical"
    )

TRAEFIK_HOST = get_config("TRAEFIK_HOST")
CHATBOT_API = get_config("CHATBOT_API")
