from flask import render_template, abort
from jinja2 import TemplateNotFound


def render(template, **kwargs):
    """Render the given template or abort the request (404) if not found"""
    try:
        return render_template(template, **kwargs)
    except TemplateNotFound:
        abort(404)
