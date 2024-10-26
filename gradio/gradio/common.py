import sys
import gradio as gr
import json
import os
import logging
import subprocess
import re
from tempfile import NamedTemporaryFile

logging.getLogger("httpcore").setLevel(logging.WARNING)
logging.getLogger("httpx").setLevel(logging.WARNING)

APP_PREFIX = "APP"
APP_ROOT = os.path.dirname(os.path.realpath(__file__))
APP = os.getenv(f"{APP_PREFIX}_APP")


def get_config(key, default=None):
    """Get config from an environment variable or use the default if not set"""
    key = f"{APP_PREFIX}_{key.upper().replace(' ','_')}"
    value = os.getenv(key, default)
    if default == None and (value == "" or value == None):
        raise ConfigError(f"Required config value is blank: {key}")
    # print(f"{key}={value}");
    # sys.stdout.flush();
    return value


def get_logger(name):
    """Gradio compatible flushing logger with log level filtering"""

    class Logger:
        def __init__(self, name):
            self.name = name

            LOG_LEVEL = get_config("LOG_LEVEL", "WARNING").upper()
            if LOG_LEVEL in ("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"):
                LOG_LEVEL = getattr(logging, LOG_LEVEL)
                logging.basicConfig(level=LOG_LEVEL, force=True)
                # print("Logging level set: {}".format(logging.getLevelName(LOG_LEVEL)))
                # sys.stdout.flush()
            else:
                invalid_config(
                    "LOG_LEVEL",
                    f"{repr(LOG_LEVEL)} - use debug, info, warning, error, or critical",
                )

            self.level = logging.getLogger().getEffectiveLevel()
            sys.stdout.flush()

        def _log(self, level, message):
            if level >= self.level:
                print(f"[{logging.getLevelName(level)}] {self.name}: {message}")
                sys.stdout.flush()

        def info(self, message):
            self._log(logging.INFO, message)

        def error(self, message):
            print(f"[ERROR] {self.name}: {message}", file=sys.stderr)
            sys.stderr.flush()

        def warning(self, message):
            self._log(logging.WARNING, message)

        def warn(self, message):
            self.warning(message)

        def debug(self, message):
            self._log(logging.DEBUG, message)

        def set_level(self, level):
            if isinstance(level, int):
                self.level = level
            else:
                try:
                    self.level = getattr(logging, level.upper())
                except AttributeError:
                    print(f"Invalid log level: {level}")

    return Logger(name)


def clean_markdown(text):
    # Remove Markdown links (but keep the link text)
    text = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", text)
    # Remove Markdown bold and italic markers
    text = re.sub(r"(\*\*|__)(.*?)\1", r"\2", text)  # Bold
    text = re.sub(r"(\*|_)(.*?)\1", r"\2", text)  # Italic
    # Remove Markdown headers
    text = re.sub(r"#+\s*(.*)", r"\1", text)
    # Remove Markdown bullet points and numbered lists
    text = re.sub(r"(\*|\-|\+|\d+\.)\s+", "", text)
    # Remove code blocks and inline code formatting
    text = re.sub(r"(```.*?```|`)", "", text, flags=re.DOTALL)
    return text


log = get_logger(APP)


class ConfigError(Exception):
    """A config error exception"""


def invalid_config(variable, error_message):
    "Log error for invalid configuration and quit"
    log.error(
        f"Invalid configuration for variable {APP_PREFIX}_{variable}: {error_message}"
    )
    exit(1)


def launch(interface, **kwargs):
    log.info(f"URL: https://{TRAEFIK_HOST}")
    kwargs["server_name"] = kwargs.get("server_name", "0.0.0.0")
    kwargs["server_port"] = kwargs.get("server_port", 7860)
    log.info(kwargs)
    interface.launch(**kwargs)


TRAEFIK_HOST = get_config("TRAEFIK_HOST")
MODE = get_config("MODE")
