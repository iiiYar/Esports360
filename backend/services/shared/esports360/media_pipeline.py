from __future__ import annotations

import hashlib
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path
from typing import Any
from uuid import UUID

import httpx
from PIL import Image, ImageDraw, ImageFont, ImageOps, UnidentifiedImageError
from psycopg import Connection
from psycopg.types.json import Jsonb

from .config import get_settings
from .object_storage import object_exists, put_object, using_minio


IMAGE_VARIANTS = {
    "xs": 64,
    "sm": 128,
    "md": 256,
    "lg": 512,
}


@dataclass(frozen=True)
class ImageBackfillResult:
    processed: int
    succeeded: int
    failed: int
    skipped: int


def _checksum(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _public_url(storage_key: str) -> str:
    base_url = get_settings().media_public_base_url.rstrip("/")
    return f"{base_url}/{storage_key}"


def _storage_path(storage_key: str) -> Path:
    return Path(get_settings().media_storage_dir) / storage_key


def _write_variant(storage_key: str, image: Image.Image) -> tuple[str, int]:
    output = BytesIO()
    image.save(output, format="PNG", optimize=True)
    data = output.getvalue()
    if using_minio():
        put_object(storage_key, data, content_type="image/png")
    else:
        path = _storage_path(storage_key)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return _checksum(data), len(data)


def _png_bytes(image: Image.Image) -> bytes:
    output = BytesIO()
    image.save(output, format="PNG", optimize=True)
    return output.getvalue()


def _fit_image(source: Image.Image, size: int) -> Image.Image:
    image = ImageOps.contain(source, (size, size), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = ((size - image.width) // 2, (size - image.height) // 2)
    canvas.alpha_composite(image, offset)
    return canvas


def _download_image(source_url: str) -> bytes:
    with httpx.Client(timeout=30, follow_redirects=True) as client:
        response = client.get(source_url, headers={"User-Agent": "Esports360/1.0"})
        response.raise_for_status()
        return response.content


def _is_svg(source_url: str, data: bytes) -> bool:
    if source_url.lower().split("?", 1)[0].endswith(".svg"):
        return True
    return data.lstrip()[:5].lower() == b"<svg "


def _tint_alpha(image: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A")
    tinted = Image.new("RGBA", image.size, (*color, 0))
    tinted.putalpha(alpha)
    return tinted


def _decode_image(source_url: str, original_bytes: bytes) -> Image.Image:
    if _is_svg(source_url, original_bytes):
        try:
            import cairosvg

            png_bytes = cairosvg.svg2png(bytestring=original_bytes, output_width=1024, output_height=1024)
        except Exception as error:  # noqa: BLE001 - normalize SVG renderer errors for image ingestion logs.
            raise OSError(f"SVG render failed: {error}") from error
        image = Image.open(BytesIO(png_bytes)).convert("RGBA")
        return _tint_alpha(image, (232, 232, 240))
    return Image.open(BytesIO(original_bytes)).convert("RGBA")


def _font(size: int) -> ImageFont.ImageFont:
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    ):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


GAME_LOGO_PALETTE = {
    "lol": ("#0a1428", "#c89b3c"),
    "valorant": ("#111823", "#ff4655"),
    "cs2": ("#101316", "#f59e0b"),
    "dota2": ("#171111", "#a33327"),
    "rocket-league": ("#0d1b2a", "#38bdf8"),
    "overwatch-2": ("#111115", "#f97316"),
    "rainbow-six-siege": ("#101820", "#d1d5db"),
    "pubg": ("#19130d", "#fbbf24"),
    "mobile-legends": ("#101827", "#60a5fa"),
    "wild-rift": ("#0d1b2a", "#22d3ee"),
    "ea-fc": ("#0b1412", "#06d6a0"),
    "starcraft-2": ("#111827", "#818cf8"),
}


def _hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))


def _render_game_logo(code: str, name: str, short_name: str | None, genre: str | None) -> Image.Image:
    background_hex, accent_hex = GAME_LOGO_PALETTE.get(code, ("#111115", "#7c3aed"))
    background = _hex_rgb(background_hex)
    accent = _hex_rgb(accent_hex)
    image = Image.new("RGBA", (1024, 1024), (*background, 255))
    draw = ImageDraw.Draw(image)

    for index in range(0, 1024, 32):
        alpha = int(22 + (index / 1024) * 36)
        draw.line([(index - 220, 1024), (index + 520, 0)], fill=(*accent, alpha), width=12)

    draw.rounded_rectangle((116, 116, 908, 908), radius=128, outline=(*accent, 190), width=8)
    draw.rounded_rectangle((156, 156, 868, 868), radius=104, outline=(255, 255, 255, 24), width=4)

    label = (short_name or code).upper()
    font_size = 260 if len(label) <= 3 else 190 if len(label) <= 5 else 136
    label_font = _font(font_size)
    label_box = draw.textbbox((0, 0), label, font=label_font)
    label_width = label_box[2] - label_box[0]
    label_height = label_box[3] - label_box[1]
    draw.text(
        ((1024 - label_width) / 2, 420 - label_height / 2),
        label,
        font=label_font,
        fill=(232, 232, 240, 255),
    )

    title = name.upper()[:26]
    title_font = _font(54)
    title_box = draw.textbbox((0, 0), title, font=title_font)
    draw.text(
        ((1024 - (title_box[2] - title_box[0])) / 2, 610),
        title,
        font=title_font,
        fill=(232, 232, 240, 210),
    )

    if genre:
        genre_text = genre.upper()[:18]
        genre_font = _font(38)
        genre_box = draw.textbbox((0, 0), genre_text, font=genre_font)
        pill_width = genre_box[2] - genre_box[0] + 76
        draw.rounded_rectangle(
            ((1024 - pill_width) / 2, 716, (1024 + pill_width) / 2, 798),
            radius=41,
            fill=(*accent, 210),
        )
        draw.text(
            ((1024 - (genre_box[2] - genre_box[0])) / 2, 736),
            genre_text,
            font=genre_font,
            fill=(13, 13, 15, 255),
        )
    return image


def _ensure_media_asset(
    connection: Connection,
    *,
    entity_type: str,
    entity_id: UUID,
    role: str,
    source: str,
    source_url: str,
    metadata: dict[str, Any] | None = None,
) -> UUID:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            select ma.id
            from entity_media em
            join media_assets ma on ma.id = em.media_asset_id
            where em.entity_type = %s
              and em.entity_id = %s
              and em.role = %s
              and ma.url = %s
            limit 1
            """,
            (entity_type, entity_id, role, source_url),
        )
        row = cursor.fetchone()
        if row:
            return row["id"]

        cursor.execute(
            """
            insert into media_assets (asset_type, source, url, mime_type, metadata)
            values ('image', %s, %s, 'image/png', %s)
            returning id
            """,
            (source, source_url, Jsonb(metadata or {})),
        )
        media_asset_id = cursor.fetchone()["id"]
        cursor.execute(
            """
            insert into entity_media (entity_type, entity_id, media_asset_id, role, is_primary)
            values (%s, %s, %s, %s, true)
            on conflict (entity_type, entity_id, media_asset_id, role) do nothing
            """,
            (entity_type, entity_id, media_asset_id, role),
        )
        return media_asset_id


def _has_variants(connection: Connection, media_asset_id: UUID) -> bool:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            select variant, storage_key
            from media_asset_variants
            where media_asset_id = %s
            """,
            (media_asset_id,),
        )
        rows = cursor.fetchall()
    if len(rows) < len(IMAGE_VARIANTS):
        return False
    if not using_minio():
        return True
    return all(object_exists(row["storage_key"]) for row in rows)


def process_image_url(
    connection: Connection,
    *,
    entity_type: str,
    entity_id: UUID,
    role: str,
    source_url: str,
    source: str = "external",
    force: bool = False,
    metadata: dict[str, Any] | None = None,
) -> int:
    media_asset_id = _ensure_media_asset(
        connection,
        entity_type=entity_type,
        entity_id=entity_id,
        role=role,
        source=source,
        source_url=source_url,
        metadata=metadata,
    )
    if not force and _has_variants(connection, media_asset_id):
        _log_image(connection, entity_type, entity_id, role, source_url, "skipped", 0, None)
        return 0

    try:
        original_bytes = _download_image(source_url)
        source_image = _decode_image(source_url, original_bytes)
    except (httpx.HTTPError, UnidentifiedImageError, OSError) as error:
        _log_image(connection, entity_type, entity_id, role, source_url, "failed", 0, str(error))
        return 0

    with connection.cursor() as cursor:
        cursor.execute(
            """
            update media_assets
            set checksum = %s,
                width = %s,
                height = %s,
                updated_at = now()
            where id = %s
            """,
            (_checksum(original_bytes), source_image.width, source_image.height, media_asset_id),
        )

    created = 0
    for variant, size in IMAGE_VARIANTS.items():
        image = _fit_image(source_image, size)
        storage_key = f"{entity_type}/{entity_id}/{role}/{variant}.png"
        checksum, byte_size = _write_variant(storage_key, image)
        with connection.cursor() as cursor:
            cursor.execute(
                """
                insert into media_asset_variants (
                    media_asset_id, variant, format, url, storage_key,
                    width, height, byte_size, checksum
                )
                values (%s, %s, 'png', %s, %s, %s, %s, %s, %s)
                on conflict (media_asset_id, variant, format) do update set
                    url = excluded.url,
                    storage_key = excluded.storage_key,
                    width = excluded.width,
                    height = excluded.height,
                    byte_size = excluded.byte_size,
                    checksum = excluded.checksum,
                    updated_at = now()
                """,
                (
                    media_asset_id,
                    variant,
                    _public_url(storage_key),
                    storage_key,
                    size,
                    size,
                    byte_size,
                    checksum,
                ),
            )
        created += 1

    _log_image(connection, entity_type, entity_id, role, source_url, "succeeded", created, None)
    return created


def process_generated_image(
    connection: Connection,
    *,
    entity_type: str,
    entity_id: UUID,
    role: str,
    source_url: str,
    image: Image.Image,
    source: str = "generated",
    force: bool = False,
    metadata: dict[str, Any] | None = None,
) -> int:
    media_asset_id = _ensure_media_asset(
        connection,
        entity_type=entity_type,
        entity_id=entity_id,
        role=role,
        source=source,
        source_url=source_url,
        metadata=metadata,
    )
    if not force and _has_variants(connection, media_asset_id):
        _log_image(connection, entity_type, entity_id, role, source_url, "skipped", 0, None)
        return 0

    source_image = image.convert("RGBA")
    source_bytes = _png_bytes(source_image)
    with connection.cursor() as cursor:
        cursor.execute(
            """
            update media_assets
            set checksum = %s,
                width = %s,
                height = %s,
                updated_at = now()
            where id = %s
            """,
            (_checksum(source_bytes), source_image.width, source_image.height, media_asset_id),
        )

    created = 0
    for variant, size in IMAGE_VARIANTS.items():
        fitted_image = _fit_image(source_image, size)
        storage_key = f"{entity_type}/{entity_id}/{role}/{variant}.png"
        checksum, byte_size = _write_variant(storage_key, fitted_image)
        with connection.cursor() as cursor:
            cursor.execute(
                """
                insert into media_asset_variants (
                    media_asset_id, variant, format, url, storage_key,
                    width, height, byte_size, checksum
                )
                values (%s, %s, 'png', %s, %s, %s, %s, %s, %s)
                on conflict (media_asset_id, variant, format) do update set
                    url = excluded.url,
                    storage_key = excluded.storage_key,
                    width = excluded.width,
                    height = excluded.height,
                    byte_size = excluded.byte_size,
                    checksum = excluded.checksum,
                    updated_at = now()
                """,
                (
                    media_asset_id,
                    variant,
                    _public_url(storage_key),
                    storage_key,
                    size,
                    size,
                    byte_size,
                    checksum,
                ),
            )
        created += 1

    _log_image(connection, entity_type, entity_id, role, source_url, "succeeded", created, None)
    return created


def _log_image(
    connection: Connection,
    entity_type: str,
    entity_id: UUID,
    role: str,
    source_url: str,
    status: str,
    variants_created: int,
    error: str | None,
) -> None:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            insert into image_ingestion_logs (
                entity_type, entity_id, role, source_url, status, variants_created, error
            )
            values (%s, %s, %s, %s, %s, %s, %s)
            """,
            (entity_type, entity_id, role, source_url, status, variants_created, error),
        )


def backfill_team_logos(connection: Connection, limit: int | None = None) -> ImageBackfillResult:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            select id, metadata #>> '{pandascore,image_url}' as source_url
            from teams
            where nullif(metadata #>> '{pandascore,image_url}', '') is not null
            order by updated_at desc
            limit %s
            """,
            (limit or get_settings().image_backfill_limit,),
        )
        rows = cursor.fetchall()

    succeeded = 0
    failed = 0
    skipped = 0
    for row in rows:
        created = process_image_url(
            connection,
            entity_type="team",
            entity_id=row["id"],
            role="logo",
            source_url=row["source_url"],
            source="pandascore",
            force=get_settings().image_backfill_force,
            metadata={"original_source": "teams.metadata.pandascore.image_url"},
        )
        if created > 0:
            succeeded += 1
        else:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    select status
                    from image_ingestion_logs
                    where entity_type = 'team' and entity_id = %s and role = 'logo'
                    order by created_at desc
                    limit 1
                    """,
                    (row["id"],),
                )
                status = cursor.fetchone()["status"]
            if status == "skipped":
                skipped += 1
            else:
                failed += 1
    return ImageBackfillResult(
        processed=len(rows),
        succeeded=succeeded,
        failed=failed,
        skipped=skipped,
    )


def _count_latest_status(
    connection: Connection,
    *,
    entity_type: str,
    entity_id: UUID,
    role: str,
) -> str:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            select status
            from image_ingestion_logs
            where entity_type = %s and entity_id = %s and role = %s
            order by created_at desc
            limit 1
            """,
            (entity_type, entity_id, role),
        )
        row = cursor.fetchone()
    return row["status"] if row else "failed"


def backfill_player_images(connection: Connection, limit: int | None = None) -> ImageBackfillResult:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            select id, metadata #>> '{pandascore,image_url}' as source_url
            from players
            where nullif(metadata #>> '{pandascore,image_url}', '') is not null
            order by updated_at desc
            limit %s
            """,
            (limit or get_settings().image_backfill_limit,),
        )
        rows = cursor.fetchall()

    succeeded = 0
    failed = 0
    skipped = 0
    for row in rows:
        created = process_image_url(
            connection,
            entity_type="player",
            entity_id=row["id"],
            role="portrait",
            source_url=row["source_url"],
            source="pandascore",
            force=get_settings().image_backfill_force,
            metadata={"original_source": "players.metadata.pandascore.image_url"},
        )
        if created > 0:
            succeeded += 1
        elif _count_latest_status(connection, entity_type="player", entity_id=row["id"], role="portrait") == "skipped":
            skipped += 1
        else:
            failed += 1

    return ImageBackfillResult(
        processed=len(rows),
        succeeded=succeeded,
        failed=failed,
        skipped=skipped,
    )


def backfill_game_logos(connection: Connection, limit: int | None = None) -> ImageBackfillResult:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            select id, code, name, short_name, genre,
                   metadata #>> '{media,logo_url}' as logo_url,
                   metadata #>> '{media,logo_source}' as logo_source
            from games
            where status = 'active'
            order by coalesce((metadata ->> 'priority')::int, 999), name
            limit %s
            """,
            (limit or get_settings().image_backfill_limit,),
        )
        rows = cursor.fetchall()

    succeeded = 0
    failed = 0
    skipped = 0
    for row in rows:
        code = str(row["code"])
        source_url = row["logo_url"]
        if source_url:
            created = process_image_url(
                connection,
                entity_type="game",
                entity_id=row["id"],
                role="logo",
                source_url=source_url,
                source=row["logo_source"] or "external",
                force=get_settings().image_backfill_force,
                metadata={"original_source": "games.metadata.media.logo_url", "game_code": code},
            )
        else:
            generated_source_url = f"generated://game-logo/{code}"
            try:
                logo = _render_game_logo(code, row["name"], row["short_name"], row["genre"])
                created = process_generated_image(
                    connection,
                    entity_type="game",
                    entity_id=row["id"],
                    role="logo",
                    source_url=generated_source_url,
                    image=logo,
                    source="generated",
                    force=get_settings().image_backfill_force,
                    metadata={"generator": "esports360.game_logo_v1", "game_code": code},
                )
            except OSError as error:
                _log_image(connection, "game", row["id"], "logo", generated_source_url, "failed", 0, str(error))
                created = 0

        if created > 0:
            succeeded += 1
        elif _count_latest_status(connection, entity_type="game", entity_id=row["id"], role="logo") == "skipped":
            skipped += 1
        else:
            failed += 1

    return ImageBackfillResult(
        processed=len(rows),
        succeeded=succeeded,
        failed=failed,
        skipped=skipped,
    )
