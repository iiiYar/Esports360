from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import UUID

from PIL import Image, ImageDraw, ImageFont
from psycopg.types.json import Jsonb

from esports360.database import connect
from esports360.media_pipeline import process_generated_image


@dataclass(frozen=True)
class FeaturedTournamentSeed:
    slug: str
    name: str
    code: str | None
    label: str
    subtitle: str
    accent: tuple[int, int, int]
    prize_pool: str
    prize_note: str
    tier: str
    location: str
    format: str
    game_summary: str
    display_order: int
    starts_at: datetime | None = None
    ends_at: datetime | None = None


TOURNAMENTS = [
    FeaturedTournamentSeed(
        slug="esports-world-cup-riyadh",
        name="Esports World Cup Riyadh",
        code=None,
        label="EWC",
        subtitle="RIYADH",
        accent=(245, 197, 66),
        prize_pool="TBA",
        prize_note="Multi-title prize pool",
        tier="global",
        location="Riyadh, Saudi Arabia",
        format="Multi-title festival",
        game_summary="CS2, Valorant, LoL, Dota 2, Rocket League +",
        display_order=1,
    ),
    FeaturedTournamentSeed(
        slug="cs2-major-championship",
        name="CS2 Major Championship",
        code="cs2",
        label="MAJOR",
        subtitle="COUNTER-STRIKE 2",
        accent=(245, 158, 11),
        prize_pool="$1.25M+",
        prize_note="Major-scale prize pool",
        tier="major",
        location="Global circuit",
        format="Swiss + Playoffs",
        game_summary="CS2",
        display_order=2,
    ),
    FeaturedTournamentSeed(
        slug="blast-premier-cs2",
        name="BLAST Premier",
        code="cs2",
        label="BLAST",
        subtitle="PREMIER",
        accent=(236, 72, 153),
        prize_pool="$1M+",
        prize_note="Season circuit",
        tier="tier-s",
        location="Global circuit",
        format="Groups + Finals",
        game_summary="CS2",
        display_order=3,
    ),
    FeaturedTournamentSeed(
        slug="valorant-champions",
        name="VALORANT Champions",
        code="valorant",
        label="VCT",
        subtitle="CHAMPIONS",
        accent=(255, 70, 85),
        prize_pool="TBA",
        prize_note="World championship prize pool",
        tier="world-championship",
        location="Global",
        format="Groups + Playoffs",
        game_summary="Valorant",
        display_order=4,
    ),
    FeaturedTournamentSeed(
        slug="league-of-legends-worlds",
        name="League of Legends World Championship",
        code="lol",
        label="WORLDS",
        subtitle="LEAGUE OF LEGENDS",
        accent=(200, 155, 60),
        prize_pool="TBA",
        prize_note="World championship prize pool",
        tier="world-championship",
        location="Global",
        format="Swiss + Knockout",
        game_summary="League of Legends",
        display_order=5,
    ),
    FeaturedTournamentSeed(
        slug="the-international-dota2",
        name="The International",
        code="dota2",
        label="TI",
        subtitle="DOTA 2",
        accent=(163, 51, 39),
        prize_pool="Crowdfunded",
        prize_note="Annual championship prize pool",
        tier="world-championship",
        location="Global",
        format="Group Stage + Playoffs",
        game_summary="Dota 2",
        display_order=6,
    ),
    FeaturedTournamentSeed(
        slug="rlcs-world-championship",
        name="RLCS World Championship",
        code="rl",
        label="RLCS",
        subtitle="ROCKET LEAGUE",
        accent=(56, 189, 248),
        prize_pool="TBA",
        prize_note="World championship prize pool",
        tier="world-championship",
        location="Global",
        format="Swiss + Playoffs",
        game_summary="Rocket League",
        display_order=7,
    ),
]


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


def _render_tournament_logo(seed: FeaturedTournamentSeed) -> Image.Image:
    image = Image.new("RGBA", (1024, 1024), (13, 13, 15, 255))
    draw = ImageDraw.Draw(image)
    accent = seed.accent

    for index in range(-260, 1280, 46):
        alpha = int(18 + (index + 260) / 1540 * 42)
        draw.line([(index, 1024), (index + 620, 0)], fill=(*accent, alpha), width=18)

    draw.rounded_rectangle((92, 92, 932, 932), radius=140, fill=(20, 20, 24, 240), outline=(*accent, 180), width=8)
    draw.rounded_rectangle((132, 132, 892, 892), radius=110, outline=(255, 255, 255, 24), width=4)

    label = seed.label.upper()
    label_size = 245 if len(label) <= 3 else 190 if len(label) <= 5 else 145
    label_font = _font(label_size)
    label_box = draw.textbbox((0, 0), label, font=label_font)
    label_width = label_box[2] - label_box[0]
    label_height = label_box[3] - label_box[1]
    draw.text(((1024 - label_width) / 2, 394 - label_height / 2), label, font=label_font, fill=(245, 245, 247, 255))

    subtitle = seed.subtitle.upper()[:24]
    subtitle_font = _font(54)
    subtitle_box = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    draw.text(
        ((1024 - (subtitle_box[2] - subtitle_box[0])) / 2, 594),
        subtitle,
        font=subtitle_font,
        fill=(*accent, 245),
    )

    tier = seed.tier.replace("-", " ").upper()[:22]
    tier_font = _font(34)
    tier_box = draw.textbbox((0, 0), tier, font=tier_font)
    pill_width = tier_box[2] - tier_box[0] + 82
    draw.rounded_rectangle(((1024 - pill_width) / 2, 718, (1024 + pill_width) / 2, 792), radius=37, fill=(*accent, 225))
    draw.text(((1024 - (tier_box[2] - tier_box[0])) / 2, 738), tier, font=tier_font, fill=(13, 13, 15, 255))
    return image


def _game_id_by_code(connection, code: str | None) -> UUID | None:
    if not code:
        return None
    with connection.cursor() as cursor:
        cursor.execute("select id from games where code = %s limit 1", (code,))
        row = cursor.fetchone()
    return row["id"] if row else None


def main() -> None:
    with connect() as connection:
        for seed in TOURNAMENTS:
            game_id = _game_id_by_code(connection, seed.code)
            metadata = {
                "featured": True,
                "tier": seed.tier,
                "location": seed.location,
                "prizeNote": seed.prize_note,
                "gameSummary": seed.game_summary,
                "displayOrder": seed.display_order,
                "seedSource": "esports360-featured-tournament-catalog",
            }
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    insert into tournaments (
                        game_id, name, slug, format, prize_pool, starts_at, ends_at,
                        status, metadata, created_at, updated_at
                    )
                    values (%s, %s, %s, %s, %s, %s, %s, 'scheduled', %s, now(), now())
                    on conflict (slug) do update set
                        game_id = coalesce(excluded.game_id, tournaments.game_id),
                        name = excluded.name,
                        format = excluded.format,
                        prize_pool = excluded.prize_pool,
                        starts_at = coalesce(excluded.starts_at, tournaments.starts_at),
                        ends_at = coalesce(excluded.ends_at, tournaments.ends_at),
                        status = case
                            when tournaments.status = 'running' then tournaments.status
                            else excluded.status
                        end,
                        metadata = tournaments.metadata || excluded.metadata,
                        updated_at = now()
                    returning id
                    """,
                    (
                        game_id,
                        seed.name,
                        seed.slug,
                        seed.format,
                        seed.prize_pool,
                        seed.starts_at,
                        seed.ends_at,
                        Jsonb(metadata),
                    ),
                )
                tournament_id = cursor.fetchone()["id"]

            process_generated_image(
                connection,
                entity_type="tournament",
                entity_id=tournament_id,
                role="logo",
                source_url=f"generated://featured-tournament/{seed.slug}",
                image=_render_tournament_logo(seed),
                source="esports360-generated",
                metadata={"seed": seed.slug, "label": seed.label, "accent": seed.accent},
            )

        connection.commit()
    print(f"seeded {len(TOURNAMENTS)} featured tournaments")


if __name__ == "__main__":
    main()
