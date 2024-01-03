import os
import logging
from logging import DEBUG
from lib.config import LOG_LEVEL, DB
from lib import db
import aiosql

log = logging.getLogger(__name__)

queries = aiosql.from_path(
    # Load the SQL from an absolute path to avoid problems with changing directories:
    os.path.join(os.path.dirname(os.path.realpath(__file__)), "upload.sql"),
    # This example uses psycopg2, but you could use any other adapter:
    # https://nackjicholson.github.io/aiosql/database-driver-adapters.html
    driver_adapter="psycopg2",
)


def create_tables_upload():
    with db() as transaction:
        log.debug("Creating database tables if they don't exist already ...")
        queries.ddl_lock(transaction)
        queries.create_enum_job_status(transaction)
        queries.create_table_upload(transaction)
        transaction.commit()


def get_user_uploads(user):
    with db() as conn:
        return queries.get_user_uploads(conn, user)

def register_upload(uploader, original_filename, upload_date,
                    upload_path, status):
    with db() as transaction:
        queries.register_upload(transaction, uploader=uploader,
                                original_filename=original_filename,
                                upload_path=upload_path,
                                upload_date=upload_date,
                                status=status)
        transaction.commit()
