import contextlib
import sqlite3
from logging import DEBUG
from .config import DB, DB_POOL_MAX_OVERFLOW, DB_POOL_SIZE

# import sqlalchemy.pool

## Common code for interfacing with Sqlite:

# maintain a connection pool to be able to reuse existing DB connections:
# connection_pool = sqlalchemy.pool.QueuePool(
#     lambda: sqlite3.connect(DB),
#     max_overflow=DB_POOL_MAX_OVERFLOW,
#     pool_size=DB_POOL_SIZE,
# )


@contextlib.contextmanager
def db():
    """Context manager for opening (and closing) the database
    connection within the same local thread as a request.
    """
    # With a database like postgres you would want to use a connection pool,
    # but with sqlite I don't think it matters?
    conn = sqlite3.connect(DB)
    with conn:
        yield conn
