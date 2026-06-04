from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from psycopg import Connection
from psycopg.types.json import Jsonb

from .json_tools import payload_hash


def parse_timestamp(value: Any) -> datetime | None:
    if not value or not isinstance(value, str):
        return None
    normalized = value.replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(normalized)
    except ValueError:
        return None


def get_provider_id(connection: Connection, code: str) -> UUID:
    with connection.cursor() as cursor:
        cursor.execute("select id from providers where code = %s", (code,))
        row = cursor.fetchone()
        if row:
            return row["id"]
        cursor.execute(
            """
            insert into providers (code, name, status)
            values (%s, %s, 'active')
            returning id
            """,
            (code, code.title()),
        )
        return cursor.fetchone()["id"]


def remember_payload(
    connection: Connection,
    *,
    provider_id: UUID,
    feed_type: str,
    payload: dict[str, Any],
    entity_type: str | None = None,
    entity_id: UUID | None = None,
    external_id: str | None = None,
    endpoint: str | None = None,
    request_params: dict[str, Any] | None = None,
    source_updated_at: datetime | None = None,
) -> UUID:
    digest = payload_hash(payload)
    with connection.cursor() as cursor:
        cursor.execute(
            """
            insert into provider_payloads (
                provider_id, feed_type, entity_type, entity_id, external_id,
                endpoint, request_params, payload, payload_hash, source_updated_at
            )
            values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            on conflict (provider_id, feed_type, external_id, payload_hash)
            do update set received_at = now()
            returning id
            """,
            (
                provider_id,
                feed_type,
                entity_type,
                entity_id,
                external_id,
                endpoint,
                Jsonb(request_params or {}),
                Jsonb(payload),
                digest,
                source_updated_at,
            ),
        )
        return cursor.fetchone()["id"]


def remember_external_id(
    connection: Connection,
    *,
    provider_id: UUID,
    entity_type: str,
    entity_id: UUID,
    external_id: str,
    external_slug: str | None = None,
    confidence: float = 1.0,
    metadata: dict[str, Any] | None = None,
) -> None:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            insert into provider_entity_map (
                provider_id, entity_type, entity_id, external_id,
                external_slug, confidence, metadata
            )
            values (%s, %s, %s, %s, %s, %s, %s)
            on conflict (provider_id, entity_type, external_id)
            do update set
                entity_id = excluded.entity_id,
                external_slug = excluded.external_slug,
                confidence = excluded.confidence,
                metadata = excluded.metadata,
                last_seen_at = now()
            """,
            (
                provider_id,
                entity_type,
                entity_id,
                external_id,
                external_slug,
                confidence,
                Jsonb(metadata or {}),
            ),
        )


def find_entity_by_external_id(
    connection: Connection,
    *,
    provider_id: UUID,
    entity_type: str,
    external_id: str | int | None,
) -> UUID | None:
    if external_id is None:
        return None
    with connection.cursor() as cursor:
        cursor.execute(
            """
            select entity_id
            from provider_entity_map
            where provider_id = %s and entity_type = %s and external_id = %s
            """,
            (provider_id, entity_type, str(external_id)),
        )
        row = cursor.fetchone()
        return row["entity_id"] if row else None

