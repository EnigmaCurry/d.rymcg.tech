import os
import logging
from logging import DEBUG
from lib.config import LOG_LEVEL, DB
from lib import db
import aiosql

log = logging.getLogger(__name__)

queries = aiosql.from_path(
    # Load the SQL from an absolute path to avoid problems with changing directories:
    os.path.join(os.path.dirname(os.path.realpath(__file__)), "hello.sql"),
    # This example uses psycopg2, but you could use any other adapter:
    # https://nackjicholson.github.io/aiosql/database-driver-adapters.html
    driver_adapter="psycopg2",
)


def create_tables_hello():
    with db() as transaction:
        log.debug("Creating database tables if they don't exist already ...")
        queries.ddl_lock(transaction)
        queries.create_table_visitor(transaction)
        queries.create_index_visitor_name(transaction)
        transaction.commit()


def log_user_encounter(username, salutation, ip_address):
    """Record an encounter with a user"""
    with db() as transaction:
        queries.log_user_encounter(transaction,
                                   username=username,
                                   salutation=salutation,
                                   ip_address=ip_address)
        transaction.commit()

def count_user_encounters(username):
    """Return how many times a user has been greeted"""
    with db() as conn:
        times_greeted = queries.count_user_encounters(conn, username=username)
        if times_greeted is None:
            return 0
        else:
            return times_greeted

def top_visitors():
    """Return the top 10 visitors"""
    with db() as conn:
        return queries.top_visitors(conn)
