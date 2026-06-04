from __future__ import annotations

from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from .config import get_settings
from .database import connect
from .json_tools import to_jsonable


def _entity_image_sql(entity_type: str, alias: str, role: str, fallback_sql: str = "null") -> str:
    return f"""
coalesce(
    (
        select jsonb_build_object(
            'sourceUrl', ma.url,
            'variants', coalesce(
                (
                    select jsonb_object_agg(
                        mav.variant,
                        jsonb_build_object(
                            'url', mav.url,
                            'width', mav.width,
                            'height', mav.height,
                            'format', mav.format
                        )
                    )
                    from media_asset_variants mav
                    where mav.media_asset_id = ma.id
                ),
                '{{}}'::jsonb
            )
        )
        from entity_media em
        join media_assets ma on ma.id = em.media_asset_id
        where em.entity_type = '{entity_type}'
          and em.entity_id = {alias}.id
          and em.role = '{role}'
        order by em.is_primary desc, em.created_at desc
        limit 1
    ),
    {fallback_sql}
)
"""


TEAM_IMAGE_SQL = _entity_image_sql(
    "team",
    "team",
    "logo",
    """
    case
        when nullif(team.metadata #>> '{pandascore,image_url}', '') is not null then
            jsonb_build_object(
                'sourceUrl', team.metadata #>> '{pandascore,image_url}',
                'variants', '{}'::jsonb
            )
        else null
    end
    """,
)

PLAYER_IMAGE_SQL = _entity_image_sql(
    "player",
    "p",
    "portrait",
    """
    case
        when nullif(p.metadata #>> '{pandascore,image_url}', '') is not null then
            jsonb_build_object(
                'sourceUrl', p.metadata #>> '{pandascore,image_url}',
                'variants', '{}'::jsonb
            )
        else null
    end
    """,
)

GAME_IMAGE_SQL = _entity_image_sql("game", "g", "logo")


def _status_filter(kind: str) -> tuple[str, list[object]]:
    settings = get_settings()
    now = datetime.now(ZoneInfo(settings.app_timezone))
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    tomorrow_start = today_start + timedelta(days=1)

    if kind == "live":
        return "m.status = 'live'", []
    if kind == "upcoming":
        return "m.scheduled_at >= %s and m.status in ('scheduled', 'pre_match', 'postponed')", [now]
    return "m.scheduled_at >= %s and m.scheduled_at < %s", [today_start, tomorrow_start]


def list_matches(kind: str = "today", limit: int = 50) -> list[dict[str, object]]:
    where_sql, params = _status_filter(kind)
    sql = f"""
        select
            m.id,
            m.name,
            m.status,
            m.scheduled_at as "scheduledAt",
            m.begin_at as "beginAt",
            m.end_at as "endAt",
            m.best_of as "bestOf",
            m.importance_score as "importanceScore",
            jsonb_build_object(
                'id', g.id,
                'code', g.code,
                'name', g.name,
                'shortName', g.short_name,
                'imageUrl', ({GAME_IMAGE_SQL}) #>> '{{variants,sm,url}}',
                'image', {GAME_IMAGE_SQL}
            ) as game,
            case when t.id is null then null else jsonb_build_object(
                'id', t.id,
                'name', t.name,
                'leagueName', l.name,
                'seriesName', s.name,
                'beginAt', t.starts_at,
                'endAt', t.ends_at,
                'imageUrl', coalesce(
                    (
                        select mav.url
                        from entity_media em
                        join media_asset_variants mav on mav.media_asset_id = em.media_asset_id
                        where em.entity_type = 'tournament'
                          and em.entity_id = t.id
                          and em.role = 'logo'
                          and mav.variant = 'sm'
                          and mav.format = 'png'
                        order by em.is_primary desc, mav.updated_at desc
                        limit 1
                    ),
                    (
                        select mav.url
                        from entity_media em
                        join media_asset_variants mav on mav.media_asset_id = em.media_asset_id
                        where em.entity_type = 'league'
                          and em.entity_id = t.league_id
                          and em.role = 'logo'
                          and mav.variant = 'sm'
                          and mav.format = 'png'
                        order by em.is_primary desc, mav.updated_at desc
                        limit 1
                    ),
                    l.metadata #>> '{{pandascore,image_url}}'
                )
            ) end as tournament,
            coalesce(
                jsonb_agg(
                    jsonb_build_object(
                        'id', team.id,
                        'name', team.name,
                        'acronym', team.short_name,
                        'countryCode', team.country_code,
                        'score', mp.score,
                        'result', mp.result,
                        'side', mp.side,
                        'imageUrl', coalesce(
                            (
                                select mav.url
                                from entity_media em
                                join media_asset_variants mav on mav.media_asset_id = em.media_asset_id
                                where em.entity_type = 'team'
                                  and em.entity_id = team.id
                                  and em.role = 'logo'
                                  and mav.variant = 'sm'
                                  and mav.format = 'png'
                                order by em.is_primary desc, mav.updated_at desc
                                limit 1
                            ),
                            team.metadata #>> '{{pandascore,image_url}}'
                        ),
                        'image', {TEAM_IMAGE_SQL}
                    )
                    order by mp.seed nulls last, mp.side
                ) filter (where mp.id is not null),
                '[]'::jsonb
            ) as teams
        from matches m
        left join games g on g.id = m.game_id
        left join tournaments t on t.id = m.tournament_id
        left join leagues l on l.id = m.league_id
        left join series s on s.id = m.series_id
        left join match_participants mp on mp.match_id = m.id
        left join teams team on team.id = mp.team_id
        where {where_sql}
        group by m.id, g.id, t.id, l.id, s.id
        order by
            case when m.status = 'live' then 0 else 1 end,
            m.scheduled_at nulls last,
            m.importance_score desc
        limit %s
    """
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(sql, [*params, limit])
            return [to_jsonable(row) for row in cursor.fetchall()]


def list_games(limit: int = 50) -> list[dict[str, object]]:
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                f"""
                select g.id,
                       g.code,
                       g.name,
                       g.short_name as "shortName",
                       g.genre,
                       g.publisher,
                       g.status,
                       ({GAME_IMAGE_SQL}) #>> '{{variants,sm,url}}' as "imageUrl",
                       {GAME_IMAGE_SQL} as image
                from games g
                order by coalesce((g.metadata ->> 'priority')::int, 999), g.name
                limit %s
                """,
                (limit,),
            )
            return [to_jsonable(row) for row in cursor.fetchall()]


def list_featured_teams(limit: int = 20) -> list[dict[str, object]]:
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                f"""
                select team.id,
                       team.name,
                       team.short_name as "shortName",
                       team.slug,
                       team.country_code as "countryCode",
                       team.is_saudi as "isSaudi",
                       coalesce(
                           (
                               select mav.url
                               from entity_media em
                               join media_asset_variants mav on mav.media_asset_id = em.media_asset_id
                               where em.entity_type = 'team'
                                 and em.entity_id = team.id
                                 and em.role = 'logo'
                                 and mav.variant = 'sm'
                                 and mav.format = 'png'
                               order by em.is_primary desc, mav.updated_at desc
                               limit 1
                           ),
                           team.metadata #>> '{{pandascore,image_url}}'
                       ) as "imageUrl",
                       {TEAM_IMAGE_SQL} as image,
                       case when g.id is null then null else jsonb_build_object(
                           'id', g.id,
                           'code', g.code,
                           'name', g.name,
                           'shortName', g.short_name,
                           'imageUrl', ({GAME_IMAGE_SQL}) #>> '{{variants,sm,url}}',
                           'image', {GAME_IMAGE_SQL}
                       ) end as game,
                       (
                           select count(*)
                           from team_memberships tm
                           where tm.team_id = team.id and tm.active_to is null
                       ) as "rosterCount"
                from teams team
                left join games g on g.id = team.primary_game_id
                where team.is_saudi = true
                   or exists (
                       select 1
                       from team_memberships tm
                       where tm.team_id = team.id and tm.active_to is null
                   )
                order by team.is_saudi desc,
                         "rosterCount" desc,
                         team.name
                limit %s
                """,
                (limit,),
            )
            return [to_jsonable(row) for row in cursor.fetchall()]


def get_match(match_id: str) -> dict[str, object] | None:
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                f"""
                select
                    m.id,
                    m.name,
                    m.status,
                    m.scheduled_at as "scheduledAt",
                    m.begin_at as "beginAt",
                    m.end_at as "endAt",
                    m.best_of as "bestOf",
                    m.importance_score as "importanceScore",
                    m.metadata,
                    jsonb_build_object(
                        'id', g.id,
                        'code', g.code,
                        'name', g.name,
                        'shortName', g.short_name,
                        'imageUrl', ({GAME_IMAGE_SQL}) #>> '{{variants,sm,url}}',
                        'image', {GAME_IMAGE_SQL}
                    ) as game,
                    case when t.id is null then null else jsonb_build_object(
                        'id', t.id,
                        'name', t.name,
                        'leagueName', l.name,
                        'seriesName', s.name,
                        'beginAt', t.starts_at,
                        'endAt', t.ends_at,
                        'imageUrl', coalesce(
                            (
                                select mav.url
                                from entity_media em
                                join media_asset_variants mav on mav.media_asset_id = em.media_asset_id
                                where em.entity_type = 'tournament'
                                  and em.entity_id = t.id
                                  and em.role = 'logo'
                                  and mav.variant = 'sm'
                                  and mav.format = 'png'
                                order by em.is_primary desc, mav.updated_at desc
                                limit 1
                            ),
                            (
                                select mav.url
                                from entity_media em
                                join media_asset_variants mav on mav.media_asset_id = em.media_asset_id
                                where em.entity_type = 'league'
                                  and em.entity_id = t.league_id
                                  and em.role = 'logo'
                                  and mav.variant = 'sm'
                                  and mav.format = 'png'
                                order by em.is_primary desc, mav.updated_at desc
                                limit 1
                            ),
                            l.metadata #>> '{{pandascore,image_url}}'
                        )
                    ) end as tournament,
                    coalesce(
                        jsonb_agg(
                            jsonb_build_object(
                                'id', team.id,
                                'name', team.name,
                                'acronym', team.short_name,
                                'countryCode', team.country_code,
                                'score', mp.score,
                                'result', mp.result,
                                'side', mp.side,
                                'imageUrl', coalesce(
                                    (
                                        select mav.url
                                        from entity_media em
                                        join media_asset_variants mav on mav.media_asset_id = em.media_asset_id
                                        where em.entity_type = 'team'
                                          and em.entity_id = team.id
                                          and em.role = 'logo'
                                          and mav.variant = 'sm'
                                          and mav.format = 'png'
                                        order by em.is_primary desc, mav.updated_at desc
                                        limit 1
                                    ),
                                    team.metadata #>> '{{pandascore,image_url}}'
                                ),
                                'image', {TEAM_IMAGE_SQL}
                            )
                            order by mp.seed nulls last, mp.side
                        ) filter (where mp.id is not null),
                        '[]'::jsonb
                    ) as teams,
                    case
                        when lms.match_id is not null then jsonb_build_object(
                            'mapNumber', coalesce(
                                case
                                    when (lms.state ->> 'mapNumber') ~ '^[0-9]+$'
                                    then (lms.state ->> 'mapNumber')::int
                                    else null
                                end,
                                (
                                    select mg.game_number
                                    from match_games mg
                                    where mg.match_id = m.id
                                      and mg.status in ('live', 'running', 'in_progress')
                                    order by mg.game_number desc
                                    limit 1
                                ),
                                1
                            ),
                            'roundNumber', case
                                when (lms.state ->> 'roundNumber') ~ '^[0-9]+$'
                                then (lms.state ->> 'roundNumber')::int
                                else null
                            end,
                            'clock', nullif(lms.state ->> 'clock', ''),
                            'phase', coalesce(nullif(lms.state ->> 'phase', ''), lms.status, 'Live')
                        )
                        when m.status = 'live' then jsonb_build_object(
                            'mapNumber', coalesce(
                                (
                                    select mg.game_number
                                    from match_games mg
                                    where mg.match_id = m.id
                                      and mg.status in ('live', 'running', 'in_progress')
                                    order by mg.game_number desc
                                    limit 1
                                ),
                                1
                            ),
                            'roundNumber', null,
                            'clock', null,
                            'phase', 'Live'
                        )
                        else null
                    end as "liveState"
                from matches m
                left join games g on g.id = m.game_id
                left join tournaments t on t.id = m.tournament_id
                left join leagues l on l.id = m.league_id
                left join series s on s.id = m.series_id
                left join match_participants mp on mp.match_id = m.id
                left join teams team on team.id = mp.team_id
                left join live_match_states lms on lms.match_id = m.id
                where m.id = %s
                group by m.id, g.id, t.id, l.id, s.id, lms.match_id, lms.state, lms.status
                """,
                (match_id,),
            )
            match = cursor.fetchone()
            if not match:
                return None
            cursor.execute(
                """
                select mg.id,
                       mg.game_number as number,
                       mg.map_name as "mapName",
                       mg.status,
                       mg.started_at as "startedAt",
                       mg.ended_at as "endedAt",
                       mg.duration_seconds as "durationSeconds",
                       mg.metadata
                from match_games mg
                where mg.match_id = %s
                order by mg.game_number
                """,
                (match_id,),
            )
            games = cursor.fetchall()
            cursor.execute(
                """
                select le.sequence,
                       le.event_type as "eventType",
                       le.occurred_at as "occurredAt",
                       le.payload
                from live_events le
                where le.match_id = %s
                order by le.sequence desc
                limit 50
                """,
                (match_id,),
            )
            events = cursor.fetchall()
            cursor.execute(
                """
                select s.id,
                       coalesce(s.title, cc.display_name, 'Live stream') as title,
                       coalesce(s.metadata ->> 'channel_type', cc.channel_type, 'other') as provider,
                       s.language,
                       s.url,
                       s.thumbnail_url as "thumbnailUrl",
                       s.viewer_count as "viewerCount",
                       s.is_live as "isLive",
                       coalesce((s.metadata ->> 'official')::boolean, cc.is_official, false) as official
                from streams s
                left join content_channels cc on cc.id = s.channel_id
                where s.match_id = %s
                  and s.url is not null
                order by s.is_live desc,
                         coalesce((s.metadata ->> 'official')::boolean, cc.is_official, false) desc,
                         s.viewer_count desc nulls last,
                         s.last_checked_at desc nulls last
                limit 8
                """,
                (match_id,),
            )
            streams = cursor.fetchall()
    payload = dict(match)
    payload["games"] = games
    payload["events"] = events
    payload["streams"] = streams
    return to_jsonable(payload)


def get_team(team_id: str) -> dict[str, object] | None:
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                f"""
                select team.id,
                       team.name,
                       team.short_name as "shortName",
                       team.slug,
                       team.country_code as "countryCode",
                       team.is_saudi as "isSaudi",
                       {TEAM_IMAGE_SQL} as image,
                       case when g.id is null then null else jsonb_build_object(
                           'id', g.id,
                           'code', g.code,
                           'name', g.name,
                           'shortName', g.short_name,
                           'imageUrl', ({GAME_IMAGE_SQL}) #>> '{{variants,sm,url}}',
                           'image', {GAME_IMAGE_SQL}
                       ) end as game,
                       team.metadata
                from teams team
                left join games g on g.id = team.primary_game_id
                where team.id = %s
                """,
                (team_id,),
            )
            team = cursor.fetchone()
            if not team:
                return None
            cursor.execute(
                f"""
                select p.id,
                       p.handle,
                       p.real_name as "realName",
                       tm.role,
                       tm.is_starter as "isStarter",
                       coalesce(
                           (
                               select mav.url
                               from entity_media em
                               join media_asset_variants mav on mav.media_asset_id = em.media_asset_id
                               where em.entity_type = 'player'
                                 and em.entity_id = p.id
                                 and em.role = 'portrait'
                                 and mav.variant = 'sm'
                                 and mav.format = 'png'
                               order by em.is_primary desc, mav.updated_at desc
                               limit 1
                           ),
                           p.metadata #>> '{{pandascore,image_url}}'
                       ) as "imageUrl",
                       {PLAYER_IMAGE_SQL} as image
                from team_memberships tm
                join players p on p.id = tm.player_id
                where tm.team_id = %s and tm.active_to is null
                order by tm.is_starter desc nulls last, p.handle
                """,
                (team_id,),
            )
            roster = cursor.fetchall()
    payload = dict(team)
    payload["roster"] = roster
    return to_jsonable(payload)


def get_tournament(tournament_id: str) -> dict[str, object] | None:
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                select t.id, t.name, t.slug, t.format,
                       t.prize_pool as "prizePool",
                       t.starts_at as "startsAt",
                       t.ends_at as "endsAt",
                       t.status,
                       t.metadata,
                       g.name as "gameName",
                       l.name as "leagueName",
                       s.name as "seriesName",
                       coalesce(
                           (
                               select mav.url
                               from entity_media em
                               join media_asset_variants mav on mav.media_asset_id = em.media_asset_id
                               where em.entity_type = 'tournament'
                                 and em.entity_id = t.id
                                 and em.role = 'logo'
                                 and mav.variant = 'sm'
                                 and mav.format = 'png'
                               order by em.is_primary desc, mav.updated_at desc
                               limit 1
                           ),
                           (
                               select mav.url
                               from entity_media em
                               join media_asset_variants mav on mav.media_asset_id = em.media_asset_id
                               where em.entity_type = 'league'
                                 and em.entity_id = t.league_id
                                 and em.role = 'logo'
                                 and mav.variant = 'sm'
                                 and mav.format = 'png'
                               order by em.is_primary desc, mav.updated_at desc
                               limit 1
                           ),
                           l.metadata #>> '{pandascore,image_url}'
                       ) as "imageUrl"
                from tournaments t
                left join games g on g.id = t.game_id
                left join leagues l on l.id = t.league_id
                left join series s on s.id = t.series_id
                where t.id = %s
                """,
                (tournament_id,),
            )
            tournament = cursor.fetchone()
            if not tournament:
                return None
            cursor.execute(
                """
                select ts.id,
                       ts.name,
                       ts.stage_type as "stageType",
                       ts.sort_order as "sortOrder"
                from tournament_stages ts
                where ts.tournament_id = %s
                order by ts.sort_order
                """,
                (tournament_id,),
            )
            stages = cursor.fetchall()
    payload = dict(tournament)
    payload["stages"] = stages
    return to_jsonable(payload)
