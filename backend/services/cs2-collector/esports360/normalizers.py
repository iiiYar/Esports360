from __future__ import annotations

from datetime import date
from typing import Any
from uuid import UUID

from psycopg import Connection
from psycopg.types.json import Jsonb

from .storage import (
    find_entity_by_external_id,
    get_provider_id,
    parse_timestamp,
    remember_external_id,
    remember_payload,
)


def _external_id(value: dict[str, Any]) -> str | None:
    raw_id = value.get("id")
    return str(raw_id) if raw_id is not None else None


def _slug(value: dict[str, Any]) -> str | None:
    raw_slug = value.get("slug")
    return str(raw_slug) if raw_slug else None


def _name(value: dict[str, Any], fallback: str = "Unknown") -> str:
    return str(value.get("name") or value.get("full_name") or fallback)


PANDASCORE_GAME_CODE_MAP = {
    "league-of-legends": "lol",
    "lol": "lol",
    "valorant": "valorant",
    "counter-strike": "cs2",
    "cs-go": "cs2",
    "cs2": "cs2",
    "dota-2": "dota2",
    "dota2": "dota2",
    "rocket-league": "rocket-league",
    "overwatch": "overwatch-2",
    "overwatch-2": "overwatch-2",
    "rainbow-six-siege": "rainbow-six-siege",
    "pubg": "pubg",
    "mobile-legends-bang-bang": "mobile-legends",
    "mobile-legends": "mobile-legends",
    "lol-wild-rift": "wild-rift",
    "wild-rift": "wild-rift",
    "ea-sports-fc": "ea-fc",
    "ea-fc": "ea-fc",
    "starcraft-2": "starcraft-2",
}


def normalize_videogame(connection: Connection, provider_id: UUID, data: dict[str, Any]) -> UUID:
    provider_slug = _slug(data) or _name(data).lower().replace(" ", "-")
    code = PANDASCORE_GAME_CODE_MAP.get(provider_slug, provider_slug)
    with connection.cursor() as cursor:
        cursor.execute(
            """
            insert into games (code, name, short_name, publisher, metadata)
            values (%s, %s, %s, %s, %s)
            on conflict (code) do update set
                name = excluded.name,
                short_name = coalesce(excluded.short_name, games.short_name),
                metadata = games.metadata || excluded.metadata,
                updated_at = now()
            returning id
            """,
            (
                code,
                _name(data),
                data.get("acronym"),
                data.get("publisher"),
                Jsonb({"pandascore": {"id": data.get("id"), "slug": data.get("slug")}}),
            ),
        )
        game_id = cursor.fetchone()["id"]

    external_id = _external_id(data)
    if external_id:
        remember_external_id(
            connection,
            provider_id=provider_id,
            entity_type="game",
            entity_id=game_id,
            external_id=external_id,
            external_slug=_slug(data),
        )
    return game_id


def _normalize_nested_game(connection: Connection, provider_id: UUID, data: dict[str, Any]) -> UUID | None:
    videogame = data.get("videogame")
    if isinstance(videogame, dict):
        return normalize_videogame(connection, provider_id, videogame)
    return find_entity_by_external_id(connection, provider_id=provider_id, entity_type="game", external_id=data.get("videogame_id"))


def _normalize_current_game(connection: Connection, provider_id: UUID, data: dict[str, Any]) -> UUID | None:
    videogame = data.get("current_videogame") or data.get("videogame")
    if isinstance(videogame, dict):
        return normalize_videogame(connection, provider_id, videogame)
    return None


def _parse_date(value: Any) -> date | None:
    if not value:
        return None
    try:
        return date.fromisoformat(str(value)[:10])
    except ValueError:
        return None


def normalize_league(connection: Connection, provider_id: UUID, data: dict[str, Any], game_id: UUID | None) -> UUID | None:
    league = data.get("league") if "league" in data else data
    if not isinstance(league, dict) or not league.get("id"):
        return None
    with connection.cursor() as cursor:
        cursor.execute(
            """
            insert into leagues (game_id, name, slug, metadata)
            values (%s, %s, %s, %s)
            on conflict (slug) do update set
                game_id = coalesce(excluded.game_id, leagues.game_id),
                name = excluded.name,
                metadata = leagues.metadata || excluded.metadata,
                updated_at = now()
            returning id
            """,
            (
                game_id,
                _name(league),
                _slug(league),
                Jsonb({"pandascore": {"id": league.get("id"), "image_url": league.get("image_url")}}),
            ),
        )
        league_id = cursor.fetchone()["id"]

    remember_external_id(
        connection,
        provider_id=provider_id,
        entity_type="league",
        entity_id=league_id,
        external_id=str(league["id"]),
        external_slug=_slug(league),
    )
    return league_id


def normalize_series(
    connection: Connection,
    provider_id: UUID,
    data: dict[str, Any],
    game_id: UUID | None,
    league_id: UUID | None,
) -> UUID | None:
    serie = data.get("serie") if "serie" in data else data
    if not isinstance(serie, dict) or not serie.get("id"):
        return None
    with connection.cursor() as cursor:
        cursor.execute(
            """
            insert into series (
                league_id, game_id, name, slug, year, starts_at, ends_at, status, metadata
            )
            values (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            on conflict (slug) do update set
                league_id = coalesce(excluded.league_id, series.league_id),
                game_id = coalesce(excluded.game_id, series.game_id),
                name = excluded.name,
                year = coalesce(excluded.year, series.year),
                starts_at = coalesce(excluded.starts_at, series.starts_at),
                ends_at = coalesce(excluded.ends_at, series.ends_at),
                metadata = series.metadata || excluded.metadata,
                updated_at = now()
            returning id
            """,
            (
                league_id,
                game_id,
                _name(serie),
                _slug(serie),
                serie.get("year"),
                parse_timestamp(serie.get("begin_at")),
                parse_timestamp(serie.get("end_at")),
                "unknown",
                Jsonb({"pandascore": {"id": serie.get("id"), "full_name": serie.get("full_name")}}),
            ),
        )
        series_id = cursor.fetchone()["id"]

    remember_external_id(
        connection,
        provider_id=provider_id,
        entity_type="series",
        entity_id=series_id,
        external_id=str(serie["id"]),
        external_slug=_slug(serie),
    )
    return series_id


def normalize_tournament(
    connection: Connection,
    provider_id: UUID,
    data: dict[str, Any],
    game_id: UUID | None,
    league_id: UUID | None,
    series_id: UUID | None,
) -> UUID | None:
    tournament = data.get("tournament") if "tournament" in data else data
    if not isinstance(tournament, dict) or not tournament.get("id"):
        return None
    slug = _slug(tournament) or f"pandascore-tournament-{tournament['id']}"
    with connection.cursor() as cursor:
        cursor.execute(
            """
            insert into tournaments (
                series_id, league_id, game_id, name, slug, starts_at, ends_at, metadata
            )
            values (%s, %s, %s, %s, %s, %s, %s, %s)
            on conflict (slug) do update set
                series_id = coalesce(excluded.series_id, tournaments.series_id),
                league_id = coalesce(excluded.league_id, tournaments.league_id),
                game_id = coalesce(excluded.game_id, tournaments.game_id),
                name = excluded.name,
                starts_at = coalesce(excluded.starts_at, tournaments.starts_at),
                ends_at = coalesce(excluded.ends_at, tournaments.ends_at),
                metadata = tournaments.metadata || excluded.metadata,
                updated_at = now()
            returning id
            """,
            (
                series_id,
                league_id,
                game_id,
                _name(tournament),
                slug,
                parse_timestamp(tournament.get("begin_at")),
                parse_timestamp(tournament.get("end_at")),
                Jsonb({"pandascore": {"id": tournament.get("id")}}),
            ),
        )
        tournament_id = cursor.fetchone()["id"]

    remember_external_id(
        connection,
        provider_id=provider_id,
        entity_type="tournament",
        entity_id=tournament_id,
        external_id=str(tournament["id"]),
        external_slug=slug,
    )
    return tournament_id


def normalize_team(connection: Connection, provider_id: UUID, data: dict[str, Any], game_id: UUID | None = None) -> UUID:
    slug = _slug(data) or f"pandascore-team-{data.get('id')}"
    country_code = data.get("location")
    if isinstance(country_code, str):
        country_code = country_code[:2].upper()
    with connection.cursor() as cursor:
        cursor.execute(
            """
            insert into teams (
                primary_game_id, name, short_name, slug, country_code, is_saudi, metadata
            )
            values (%s, %s, %s, %s, %s, %s, %s)
            on conflict (slug) do update set
                primary_game_id = coalesce(excluded.primary_game_id, teams.primary_game_id),
                name = excluded.name,
                short_name = coalesce(excluded.short_name, teams.short_name),
                country_code = coalesce(excluded.country_code, teams.country_code),
                is_saudi = teams.is_saudi or excluded.is_saudi,
                metadata = teams.metadata || excluded.metadata,
                updated_at = now()
            returning id
            """,
            (
                game_id,
                _name(data),
                data.get("acronym"),
                slug,
                country_code,
                _name(data) in {"Team Falcons", "Twisted Minds", "Nasr Esports", "Sandrock Gaming"},
                Jsonb({"pandascore": {"id": data.get("id"), "image_url": data.get("image_url")}}),
            ),
        )
        team_id = cursor.fetchone()["id"]

    external_id = _external_id(data)
    if external_id:
        remember_external_id(
            connection,
            provider_id=provider_id,
            entity_type="team",
            entity_id=team_id,
            external_id=external_id,
            external_slug=slug,
        )
    return team_id


def normalize_player(
    connection: Connection,
    provider_id: UUID,
    data: dict[str, Any],
    game_id: UUID | None = None,
) -> UUID:
    external_id = _external_id(data)
    existing_player_id = None
    if external_id:
        existing_player_id = find_entity_by_external_id(
            connection,
            provider_id=provider_id,
            entity_type="player",
            external_id=external_id,
        )

    player_game_id = _normalize_current_game(connection, provider_id, data) or game_id
    handle = _name(data)
    slug_base = _slug(data) or f"pandascore-player-{external_id or handle.lower().replace(' ', '-')}"
    slug = f"{slug_base}-{external_id}" if external_id else slug_base
    country_code = data.get("nationality")
    if isinstance(country_code, str):
        country_code = country_code[:2].upper() or None
    real_name_parts = [data.get("first_name"), data.get("last_name")]
    real_name = " ".join(str(part).strip() for part in real_name_parts if part).strip() or None
    status = "active" if data.get("active", True) else "inactive"

    with connection.cursor() as cursor:
        if existing_player_id:
            cursor.execute(
                """
                update players
                set primary_game_id = coalesce(%s, primary_game_id),
                    handle = %s,
                    real_name = coalesce(%s, real_name),
                    slug = coalesce(%s, slug),
                    country_code = coalesce(%s, country_code),
                    birth_date = coalesce(%s, birth_date),
                    status = %s,
                    metadata = metadata || %s,
                    updated_at = now()
                where id = %s
                returning id
                """,
                (
                    player_game_id,
                    handle,
                    real_name,
                    slug,
                    country_code,
                    _parse_date(data.get("birthday")),
                    status,
                    Jsonb(
                        {
                            "pandascore": {
                                "id": data.get("id"),
                                "slug": data.get("slug"),
                                "role": data.get("role"),
                                "active": data.get("active"),
                                "image_url": data.get("image_url"),
                                "modified_at": data.get("modified_at"),
                            }
                        }
                    ),
                    existing_player_id,
                ),
            )
        else:
            cursor.execute(
                """
                insert into players (
                    primary_game_id, handle, real_name, slug, country_code,
                    birth_date, status, metadata
                )
                values (%s, %s, %s, %s, %s, %s, %s, %s)
                on conflict (slug) do update set
                    primary_game_id = coalesce(excluded.primary_game_id, players.primary_game_id),
                    handle = excluded.handle,
                    real_name = coalesce(excluded.real_name, players.real_name),
                    country_code = coalesce(excluded.country_code, players.country_code),
                    birth_date = coalesce(excluded.birth_date, players.birth_date),
                    status = excluded.status,
                    metadata = players.metadata || excluded.metadata,
                    updated_at = now()
                returning id
                """,
                (
                    player_game_id,
                    handle,
                    real_name,
                    slug,
                    country_code,
                    _parse_date(data.get("birthday")),
                    status,
                    Jsonb(
                        {
                            "pandascore": {
                                "id": data.get("id"),
                                "slug": data.get("slug"),
                                "role": data.get("role"),
                                "active": data.get("active"),
                                "image_url": data.get("image_url"),
                                "modified_at": data.get("modified_at"),
                            }
                        }
                    ),
                ),
            )
        player_id = cursor.fetchone()["id"]

    if external_id:
        remember_external_id(
            connection,
            provider_id=provider_id,
            entity_type="player",
            entity_id=player_id,
            external_id=external_id,
            external_slug=data.get("slug"),
        )
        remember_payload(
            connection,
            provider_id=provider_id,
            feed_type="pandascore_team_roster",
            entity_type="player",
            entity_id=player_id,
            external_id=external_id,
            endpoint="pandascore/team",
            payload=data,
            source_updated_at=parse_timestamp(data.get("modified_at")),
        )
    return player_id


def normalize_pandascore_team_roster(connection: Connection, team_data: dict[str, Any]) -> int:
    provider_id = get_provider_id(connection, "pandascore")
    game_id = _normalize_current_game(connection, provider_id, team_data)
    team_id = normalize_team(connection, provider_id, team_data, game_id)

    if game_id is None:
        with connection.cursor() as cursor:
            cursor.execute("select primary_game_id from teams where id = %s", (team_id,))
            game_id = cursor.fetchone()["primary_game_id"]

    if team_data.get("id") is not None:
        remember_payload(
            connection,
            provider_id=provider_id,
            feed_type="pandascore_team_roster",
            entity_type="team",
            entity_id=team_id,
            external_id=str(team_data["id"]),
            endpoint=f"/teams/{team_data['id']}",
            payload=team_data,
            source_updated_at=parse_timestamp(team_data.get("modified_at")),
        )

    count = 0
    for player in team_data.get("players") or []:
        if not isinstance(player, dict) or player.get("active") is False:
            continue
        player_game_id = _normalize_current_game(connection, provider_id, player) or game_id
        player_id = normalize_player(connection, provider_id, player, player_game_id)
        with connection.cursor() as cursor:
            cursor.execute(
                """
                select id
                from team_memberships
                where team_id = %s
                  and player_id = %s
                  and game_id is not distinct from %s
                  and active_to is null
                limit 1
                """,
                (team_id, player_id, player_game_id),
            )
            existing = cursor.fetchone()
            if existing:
                cursor.execute(
                    """
                    update team_memberships
                    set role = coalesce(%s, role),
                        jersey_name = %s,
                        is_starter = true,
                        metadata = metadata || %s,
                        updated_at = now()
                    where id = %s
                    """,
                    (
                        player.get("role"),
                        player.get("name"),
                        Jsonb({"pandascore": {"active": player.get("active"), "modified_at": player.get("modified_at")}}),
                        existing["id"],
                    ),
                )
            else:
                cursor.execute(
                    """
                    insert into team_memberships (
                        team_id, player_id, game_id, role, jersey_name, is_starter, metadata
                    )
                    values (%s, %s, %s, %s, %s, true, %s)
                    """,
                    (
                        team_id,
                        player_id,
                        player_game_id,
                        player.get("role"),
                        player.get("name"),
                        Jsonb({"pandascore": {"active": player.get("active"), "modified_at": player.get("modified_at")}}),
                    ),
                )
        count += 1
    return count


def normalize_pandascore_team_rosters(connection: Connection, teams: list[dict[str, Any]]) -> int:
    return sum(normalize_pandascore_team_roster(connection, team) for team in teams)


def _match_status(raw_status: Any) -> str:
    status = str(raw_status or "unknown").lower()
    return {
        "not_started": "scheduled",
        "not started": "scheduled",
        "running": "live",
        "finished": "completed",
        "canceled": "cancelled",
        "cancelled": "cancelled",
        "forfeit": "forfeit",
        "postponed": "postponed",
    }.get(status, status if status in {"scheduled", "pre_match", "live", "completed", "cancelled", "postponed", "forfeit"} else "unknown")


def normalize_match(connection: Connection, provider_id: UUID, data: dict[str, Any], feed_type: str) -> UUID:
    game_id = _normalize_nested_game(connection, provider_id, data)
    league_id = normalize_league(connection, provider_id, data, game_id)
    series_id = normalize_series(connection, provider_id, data, game_id, league_id)
    tournament_id = normalize_tournament(connection, provider_id, data, game_id, league_id, series_id)

    slug = _slug(data) or f"pandascore-match-{data.get('id')}"
    status = _match_status(data.get("status"))
    scheduled_at = parse_timestamp(data.get("scheduled_at"))
    begin_at = parse_timestamp(data.get("begin_at"))
    end_at = parse_timestamp(data.get("end_at"))
    best_of = data.get("number_of_games") or data.get("best_of")

    winner_team_id = find_entity_by_external_id(
        connection,
        provider_id=provider_id,
        entity_type="team",
        external_id=data.get("winner_id") if data.get("winner_type") == "Team" else None,
    )

    with connection.cursor() as cursor:
        cursor.execute(
            """
            insert into matches (
                game_id, league_id, series_id, tournament_id, name, slug, status,
                scheduled_at, begin_at, end_at, best_of, winner_team_id,
                last_provider_update_at, metadata
            )
            values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, now(), %s)
            on conflict (slug) do update set
                game_id = coalesce(excluded.game_id, matches.game_id),
                league_id = coalesce(excluded.league_id, matches.league_id),
                series_id = coalesce(excluded.series_id, matches.series_id),
                tournament_id = coalesce(excluded.tournament_id, matches.tournament_id),
                name = excluded.name,
                status = excluded.status,
                scheduled_at = coalesce(excluded.scheduled_at, matches.scheduled_at),
                begin_at = coalesce(excluded.begin_at, matches.begin_at),
                end_at = coalesce(excluded.end_at, matches.end_at),
                best_of = coalesce(excluded.best_of, matches.best_of),
                winner_team_id = coalesce(excluded.winner_team_id, matches.winner_team_id),
                last_provider_update_at = now(),
                metadata = matches.metadata || excluded.metadata,
                updated_at = now()
            returning id
            """,
            (
                game_id,
                league_id,
                series_id,
                tournament_id,
                data.get("name") or slug,
                slug,
                status,
                scheduled_at,
                begin_at,
                end_at,
                best_of,
                winner_team_id,
                Jsonb({"pandascore": {"id": data.get("id"), "feed_type": feed_type}}),
            ),
        )
        match_id = cursor.fetchone()["id"]

    if data.get("id") is not None:
        remember_external_id(
            connection,
            provider_id=provider_id,
            entity_type="match",
            entity_id=match_id,
            external_id=str(data["id"]),
            external_slug=slug,
        )

    remember_payload(
        connection,
        provider_id=provider_id,
        feed_type=feed_type,
        entity_type="match",
        entity_id=match_id,
        external_id=str(data.get("id")) if data.get("id") is not None else None,
        endpoint="pandascore",
        payload=data,
        source_updated_at=parse_timestamp(data.get("modified_at")),
    )

    _normalize_match_participants(connection, provider_id, match_id, game_id, data)
    _normalize_match_games(connection, provider_id, match_id, data)
    _normalize_match_streams(connection, provider_id, match_id, tournament_id, data)
    _upsert_live_state(connection, provider_id, match_id, status, data)
    return match_id


def _normalize_match_participants(
    connection: Connection,
    provider_id: UUID,
    match_id: UUID,
    game_id: UUID | None,
    data: dict[str, Any],
) -> None:
    result_by_team_id = {
        str(result.get("team_id")): result.get("score", 0)
        for result in data.get("results", [])
        if result.get("team_id") is not None
    }
    for index, item in enumerate(data.get("opponents") or []):
        opponent = item.get("opponent") if isinstance(item, dict) else None
        if not isinstance(opponent, dict):
            continue
        opponent_type = str(item.get("type") or "Team").lower()
        if opponent_type != "team":
            continue
        team_id = normalize_team(connection, provider_id, opponent, game_id)
        external_team_id = str(opponent.get("id"))
        score = result_by_team_id.get(external_team_id, 0)
        side = "team_a" if index == 0 else "team_b" if index == 1 else f"team_{index + 1}"
        result = None
        if data.get("winner_type") == "Team" and data.get("winner_id") is not None:
            result = "win" if external_team_id == str(data.get("winner_id")) else "loss"
        with connection.cursor() as cursor:
            cursor.execute(
                """
                insert into match_participants (
                    match_id, participant_type, team_id, side, seed, score, result, metadata
                )
                values (%s, 'team', %s, %s, %s, %s, %s, %s)
                on conflict (match_id, side) do update set
                    team_id = excluded.team_id,
                    score = excluded.score,
                    result = excluded.result,
                    metadata = match_participants.metadata || excluded.metadata,
                    updated_at = now()
                """,
                (
                    match_id,
                    team_id,
                    side,
                    index + 1,
                    score or 0,
                    result,
                    Jsonb({"pandascore": {"opponent_type": item.get("type")}}),
                ),
            )


def _normalize_match_games(connection: Connection, provider_id: UUID, match_id: UUID, data: dict[str, Any]) -> None:
    games = data.get("games") or []
    for item in games:
        if not isinstance(item, dict):
            continue
        position = item.get("position") or item.get("number") or 1
        winner_team_id = find_entity_by_external_id(
            connection,
            provider_id=provider_id,
            entity_type="team",
            external_id=item.get("winner_id"),
        )
        with connection.cursor() as cursor:
            cursor.execute(
                """
                insert into match_games (
                    match_id, game_number, map_name, status, started_at, ended_at,
                    winner_team_id, duration_seconds, metadata
                )
                values (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                on conflict (match_id, game_number) do update set
                    map_name = coalesce(excluded.map_name, match_games.map_name),
                    status = excluded.status,
                    started_at = coalesce(excluded.started_at, match_games.started_at),
                    ended_at = coalesce(excluded.ended_at, match_games.ended_at),
                    winner_team_id = coalesce(excluded.winner_team_id, match_games.winner_team_id),
                    duration_seconds = coalesce(excluded.duration_seconds, match_games.duration_seconds),
                    metadata = match_games.metadata || excluded.metadata,
                    updated_at = now()
                """,
                (
                    match_id,
                    position,
                    item.get("map", {}).get("name") if isinstance(item.get("map"), dict) else item.get("map_name"),
                    _match_status(item.get("status")),
                    parse_timestamp(item.get("begin_at")),
                    parse_timestamp(item.get("end_at")),
                    winner_team_id,
                    item.get("length"),
                    Jsonb({"pandascore": {"id": item.get("id"), "complete": item.get("complete")}}),
                ),
            )


def _normalize_match_streams(
    connection: Connection,
    provider_id: UUID,
    match_id: UUID,
    tournament_id: UUID | None,
    data: dict[str, Any],
) -> None:
    streams = data.get("streams_list") or []
    if not isinstance(streams, list):
        return

    with connection.cursor() as cursor:
        cursor.execute(
            """
            delete from streams
            where match_id = %s
              and provider_id = %s
              and metadata ->> 'source' = 'pandascore_streams_list'
            """,
            (match_id, provider_id),
        )

    for index, item in enumerate(streams):
        if not isinstance(item, dict):
            continue
        raw_url = item.get("raw_url") or item.get("url") or item.get("embed_url")
        if not raw_url:
            continue

        url = str(raw_url)
        lower_url = url.lower()
        channel_type = "other"
        if "twitch.tv" in lower_url:
            channel_type = "twitch"
        elif "youtube.com" in lower_url or "youtu.be" in lower_url:
            channel_type = "youtube"

        with connection.cursor() as cursor:
            cursor.execute(
                """
                insert into streams (
                    match_id, tournament_id, provider_id, external_id, title, language,
                    url, is_live, last_checked_at, metadata
                )
                values (%s, %s, %s, %s, %s, %s, %s, %s, now(), %s)
                """,
                (
                    match_id,
                    tournament_id,
                    provider_id,
                    str(item.get("id")) if item.get("id") is not None else f"pandascore:{data.get('id')}:{index}",
                    item.get("title") or item.get("name"),
                    item.get("language"),
                    url,
                    True,
                    Jsonb(
                        {
                            "source": "pandascore_streams_list",
                            "official": item.get("official"),
                            "channel_type": channel_type,
                            "raw": item,
                        }
                    ),
                ),
            )


def _upsert_live_state(connection: Connection, provider_id: UUID, match_id: UUID, status: str, data: dict[str, Any]) -> None:
    if status not in {"live", "completed"}:
        return
    state = {
        "pandascore_status": data.get("status"),
        "winner_id": data.get("winner_id"),
        "winner_type": data.get("winner_type"),
        "games_count": len(data.get("games") or []),
    }
    with connection.cursor() as cursor:
        cursor.execute(
            """
            insert into live_match_states (
                match_id, status, state, source_provider_id, provider_freshness_at, updated_at
            )
            values (%s, %s, %s, %s, now(), now())
            on conflict (match_id) do update set
                status = excluded.status,
                state = excluded.state,
                source_provider_id = excluded.source_provider_id,
                provider_freshness_at = excluded.provider_freshness_at,
                updated_at = now()
            """,
            (match_id, status, Jsonb(state), provider_id),
        )


def normalize_pandascore_matches(connection: Connection, matches: list[dict[str, Any]], feed_type: str) -> int:
    provider_id = get_provider_id(connection, "pandascore")
    count = 0
    for match in matches:
        normalize_match(connection, provider_id, match, feed_type)
        count += 1
    return count


def normalize_pandascore_videogames(connection: Connection, games: list[dict[str, Any]]) -> int:
    provider_id = get_provider_id(connection, "pandascore")
    for game in games:
        normalize_videogame(connection, provider_id, game)
        remember_payload(
            connection,
            provider_id=provider_id,
            feed_type="pandascore_videogames",
            entity_type="game",
            entity_id=find_entity_by_external_id(
                connection,
                provider_id=provider_id,
                entity_type="game",
                external_id=game.get("id"),
            ),
            external_id=str(game.get("id")) if game.get("id") is not None else None,
            endpoint="/videogames",
            payload=game,
        )
    return len(games)
