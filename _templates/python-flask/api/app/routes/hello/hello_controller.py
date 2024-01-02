from flask import request, Blueprint, session, abort
from jinja2 import TemplateNotFound
from models.hello import (
    create_tables_hello,
    increment_user_greetings,
    count_user_greetings,
    find_all_users,
)
from lib.config import WERKZEUG_RELOADING
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
    """Initialize the hello module ONCE on app startup"""
    # Only run this in the main flask thread, not the workzeug reloader, otherwise this might be called twice:
    ## https://stackoverflow.com/questions/25504149/why-does-running-the-flask-dev-server-run-itself-twice/25504196#25504196
    if not WERKZEUG_RELOADING:
        log.debug("Creating database tables if they don't exist")
        create_tables_hello()


@hello.route("/", defaults={"salutation": "hello"})
@hello.route("/<salutation>")
def greeting(salutation):
    # Gather data from the request and from the Database:
    name = request.args.get("name", "bob")
    times_greeted = increment_user_greetings(name)
    # times_greeted = count_user_greetings(name)
    # Render the view and return it:
    return render(
        f"hello/hello.html",
        salutation=salutation,
        name=name,
        times_greeted=times_greeted,
    )


@hello.route("/users")
def users():
    all_users = find_all_users()
    return render(f"hello/users.html", users=all_users)
