from psycopg2.pool import SimpleConnectionPool
from contextlib import contextmanager
from dataclasses import dataclass
import os

## Thanks Bob https://codereview.stackexchange.com/q/257671
@dataclass
class PostgresSimpleConnectionPool:

    pool: SimpleConnectionPool

    @contextmanager
    def connection(self, commit: bool = False):
        conn = self.pool.getconn()
        try:
            yield conn
            if commit:
                conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            self.pool.putconn(conn)

    @contextmanager
    def cursor(self, commit: bool = True):
        with self.connection(commit) as conn:
            with conn.cursor() as cur:
                yield cur


_connection_pool = SimpleConnectionPool(1, 10, "")
pool = PostgresSimpleConnectionPool(pool=_connection_pool)
db = pool.connection
