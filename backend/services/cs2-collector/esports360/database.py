from collections.abc import Iterator
from contextlib import contextmanager

import psycopg
from psycopg import Connection
from psycopg.rows import dict_row

from .config import get_settings


def psycopg_dsn(url: str | None = None) -> str:
    dsn = url or get_settings().database_url
    if not dsn:
        raise RuntimeError("DATABASE_URL is not configured")
    return dsn.replace("postgresql+psycopg://", "postgresql://", 1)


@contextmanager
def connect() -> Iterator[Connection]:
    with psycopg.connect(psycopg_dsn(), row_factory=dict_row) as connection:
        yield connection


def check_database() -> dict[str, object]:
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute("select 1 as ok")
            ok = cursor.fetchone()["ok"]
            cursor.execute(
                """
                select count(*) as table_count
                from information_schema.tables
                where table_schema = current_schema()
                """
            )
            table_count = cursor.fetchone()["table_count"]
    return {"ok": ok == 1, "tables": table_count}

