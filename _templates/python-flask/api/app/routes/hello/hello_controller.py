from flask import request, Blueprint, session, abort
from jinja2 import TemplateNotFound
from models.hello import (
    create_tables_hello,
    log_user_encounter,
    count_user_encounters,
    top_visitors
)
from lib.template import render
import logging

log = logging.getLogger(__name__)

# hello is an example Flask Blueprint which organizes a group of
# related routes together into a single module. This example is built
# using a model-view-controller (MVC) abstraction; with separate
# layers for data, template, and logic..

hello = Blueprint("hello", __name__, template_folder="templates")


@hello.record_once
def init(context):
    """Initialize the hello module on app startup"""
    create_tables_hello()

@hello.route("/", defaults={"salutation": "hello"})
@hello.route("/<salutation>")
def greeting(salutation):
    # Gather data from the request and from the Database:
    name = request.args.get("name", "bob")
    log_user_encounter(name, salutation, request.remote_addr)
    times_greeted = count_user_encounters(name)
    # times_greeted = count_user_greetings(name)
    # Render the view and return it:
    return render(
        f"hello/hello.html",
        salutation=salutation,
        name=name,
        times_greeted=times_greeted,
    )


@hello.route("/stats")
def stats():
    return render(f"hello/users.html", users=top_visitors())
