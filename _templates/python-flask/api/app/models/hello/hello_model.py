import os
from logging import DEBUG
from lib.config import LOG_LEVEL, DB
from lib import db
import aiosql


queries = aiosql.from_path(
    os.path.join(os.path.dirname(os.path.realpath(__file__)), "hello.sql"),
    driver_adapter="sqlite3",
)


def create_tables_hello():
    with db() as conn:
        queries.create_table_greeting(conn)


def increment_user_greetings(username):
    """Update how many times a user has been greeted and then return that number"""
    with db() as conn:
        return queries.increment_user_greetings(conn, username=username)


def count_user_greetings(username):
    """Return how many times a user has been greeted"""
    with db() as conn:
        times_greeted = queries.count_user_greetings(conn, username=username)
        if times_greeted is None:
            return 0
        else:
            return times_greeted


def find_all_users():
    """Return a list of all the users that have been greeted"""
    with db() as conn:
        return queries.get_users(conn)

