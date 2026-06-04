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


def _team_org_key_sql(alias: str) -> str:
    """Best-effort organization key for provider rows split by game.

    Some providers store the same club as separate game-specific teams, for
    example "Team Falcons" for Dota 2 and "Falcons" for CS2. This key groups
    obvious same-organization rows without merging related but distinct teams
    such as "Falcons Force" or "Riyadh Falcons".
    """
    return f"""
lower(
    trim(
        regexp_replace(
            regexp_replace(
                regexp_replace(
                    regexp_replace(coalesce({alias}.name, ''), '^team[[:space:]]+', '', 'i'),
                    '[[:space:]]+(ph|ksa|mena|academy)$',
                    '',
                    'i'
                ),
                '[[:space:]]+esports$',
                '',
                'i'
            ),
            '[[:space:]]+',
            ' ',
            'g'
        )
    )
)
"""


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
            ) as teams,
            case
                when lms.match_id is not null then jsonb_build_object(
                    'mapNumber', coalesce(
                        (
                            select mg.game_number
                            from match_games mg
                            where mg.match_id = m.id
                              and mg.status in ('live', 'running', 'in_progress')
                            order by mg.game_number desc
                            limit 1
                        ),
                        (
                            select mg.game_number
                            from match_games mg
                            where mg.match_id = m.id
                              and mg.status in ('scheduled', 'upcoming')
                            order by mg.game_number asc
                            limit 1
                        ),
                        (
                            select mg.game_number
                            from match_games mg
                            where mg.match_id = m.id
                              and mg.status in ('completed', 'finished')
                            order by mg.game_number desc
                            limit 1
                        ),
                        case
                            when (lms.state ->> 'mapNumber') ~ '^[0-9]+$'
                            then (lms.state ->> 'mapNumber')::int
                            else null
                        end,
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
                        (
                            select mg.game_number
                            from match_games mg
                            where mg.match_id = m.id
                              and mg.status in ('scheduled', 'upcoming')
                            order by mg.game_number asc
                            limit 1
                        ),
                        (
                            select mg.game_number
                            from match_games mg
                            where mg.match_id = m.id
                              and mg.status in ('completed', 'finished')
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
        where {where_sql}
        group by m.id, g.id, t.id, l.id, s.id, lms.match_id, lms.state, lms.status
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


def count_teams() -> int:
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute("select count(*) as total from teams where status <> 'disbanded'")
            row = cursor.fetchone()
            return int(row["total"] if row else 0)


def list_teams(limit: int = 50, offset: int = 0) -> list[dict[str, object]]:
    game_item_image_sql = _entity_image_sql("game", "game_item", "logo")
    team_org_key_sql = _team_org_key_sql("team")
    org_team_key_sql = _team_org_key_sql("org_team")
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
                           select count(distinct tm.id)
                           from team_memberships tm
                           join teams org_team on org_team.id = tm.team_id
                           where org_team.status <> 'disbanded'
                             and {org_team_key_sql} = {team_org_key_sql}
                             and tm.active_to is null
                       ) as "rosterCount",
                       coalesce(
                           (
                               select jsonb_agg(
                                   jsonb_build_object(
                                       'id', game_item.id,
                                       'code', game_item.code,
                                       'name', game_item.name,
                                       'shortName', game_item.short_name,
                                       'imageUrl', ({game_item_image_sql}) #>> '{{variants,sm,url}}',
                                       'image', {game_item_image_sql}
                                   )
                                   order by coalesce((game_item.metadata ->> 'priority')::int, 999), game_item.name
                               )
                               from (
                                   select distinct game_source.id
                                   from (
                                       select org_team.primary_game_id as id
                                       from teams org_team
                                       where org_team.status <> 'disbanded'
                                         and {org_team_key_sql} = {team_org_key_sql}
                                         and org_team.primary_game_id is not null
                                       union
                                       select tr.game_id as id
                                       from team_rosters tr
                                       join teams org_team on org_team.id = tr.team_id
                                       where org_team.status <> 'disbanded'
                                         and {org_team_key_sql} = {team_org_key_sql}
                                         and tr.game_id is not null
                                       union
                                       select tm.game_id as id
                                       from team_memberships tm
                                       join teams org_team on org_team.id = tm.team_id
                                       where org_team.status <> 'disbanded'
                                         and {org_team_key_sql} = {team_org_key_sql}
                                         and tm.active_to is null
                                         and tm.game_id is not null
                                       union
                                       select m.game_id as id
                                       from matches m
                                       join match_participants mp on mp.match_id = m.id
                                       join teams org_team on org_team.id = mp.team_id
                                       where org_team.status <> 'disbanded'
                                         and {org_team_key_sql} = {team_org_key_sql}
                                         and m.game_id is not null
                                   ) game_source
                                   where game_source.id is not null
                               ) distinct_games
                               join games game_item on game_item.id = distinct_games.id
                           ),
                           '[]'::jsonb
                       ) as "participatingGames"
                from teams team
                left join games g on g.id = team.primary_game_id
                where team.status <> 'disbanded'
                order by team.is_saudi desc,
                         "rosterCount" desc,
                         cardinality(string_to_array(coalesce(team.name, ''), ' ')),
                         team.name
                limit %s
                offset %s
                """,
                (limit, offset),
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
                                (
                                    select mg.game_number
                                    from match_games mg
                                    where mg.match_id = m.id
                                      and mg.status in ('live', 'running', 'in_progress')
                                    order by mg.game_number desc
                                    limit 1
                                ),
                                (
                                    select mg.game_number
                                    from match_games mg
                                    where mg.match_id = m.id
                                      and mg.status in ('scheduled', 'upcoming')
                                    order by mg.game_number asc
                                    limit 1
                                ),
                                (
                                    select mg.game_number
                                    from match_games mg
                                    where mg.match_id = m.id
                                      and mg.status in ('completed', 'finished')
                                    order by mg.game_number desc
                                    limit 1
                                ),
                                case
                                    when (lms.state ->> 'mapNumber') ~ '^[0-9]+$'
                                    then (lms.state ->> 'mapNumber')::int
                                    else null
                                end,
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
                                (
                                    select mg.game_number
                                    from match_games mg
                                    where mg.match_id = m.id
                                      and mg.status in ('scheduled', 'upcoming')
                                    order by mg.game_number asc
                                    limit 1
                                ),
                                (
                                    select mg.game_number
                                    from match_games mg
                                    where mg.match_id = m.id
                                      and mg.status in ('completed', 'finished')
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
                       coalesce(
                           (
                               select jsonb_agg(
                                   jsonb_build_object(
                                       'teamId', mgs.team_id,
                                       'totalRounds', mgs.total_rounds,
                                       'firstHalfRounds', mgs.first_half_rounds,
                                       'secondHalfRounds', mgs.second_half_rounds,
                                       'overtimeRounds', mgs.overtime_rounds,
                                       'currentSide', mgs.current_side,
                                       'updatedAt', mgs.updated_at
                                   )
                                   order by mp_score.seed nulls last, team_score.name
                               )
                               from match_game_scores mgs
                               left join match_participants mp_score
                                 on mp_score.match_id = mg.match_id
                                and mp_score.team_id = mgs.team_id
                               left join teams team_score on team_score.id = mgs.team_id
                               where mgs.match_game_id = mg.id
                           ),
                           '[]'::jsonb
                       ) as scores,
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


def get_team_games(team_id: str) -> list[dict[str, object]]:
    selected_team_key_sql = _team_org_key_sql("selected_team")
    org_team_key_sql = _team_org_key_sql("org_team")
    sql = f"""
        with selected_team as (
            select *
            from teams
            where id = %s
        ),
        org_teams as (
            select org_team.*
            from teams org_team
            cross join selected_team
            where org_team.status <> 'disbanded'
              and {org_team_key_sql} = {selected_team_key_sql}
        ),
        game_ids as (
            select primary_game_id as id
            from org_teams
            where primary_game_id is not null
            union
            select tr.game_id as id
            from team_rosters tr
            join org_teams ot on ot.id = tr.team_id
            where tr.game_id is not null
            union
            select tm.game_id as id
            from team_memberships tm
            join org_teams ot on ot.id = tm.team_id
            where tm.active_to is null and tm.game_id is not null
            union
            select m.game_id as id
            from matches m
            join match_participants mp on mp.match_id = m.id
            join org_teams ot on ot.id = mp.team_id
            where m.game_id is not null
        )
        select distinct
            g.id,
            g.code,
            g.name,
            g.short_name as "shortName",
            ({GAME_IMAGE_SQL}) #>> '{{variants,sm,url}}' as "imageUrl",
            coalesce((g.metadata ->> 'priority')::int, 999) as "_priority"
        from games g
        join game_ids gi on gi.id = g.id
        order by "_priority", g.name
    """
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(sql, (team_id,))
            rows = cursor.fetchall()
            return to_jsonable(rows)


def get_team(team_id: str) -> dict[str, object] | None:
    selected_team_key_sql = _team_org_key_sql("selected_team")
    org_team_key_sql = _team_org_key_sql("org_team")
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
                with selected_team as (
                    select *
                    from teams
                    where id = %s
                ),
                org_teams as (
                    select org_team.*
                    from teams org_team
                    cross join selected_team
                    where org_team.status <> 'disbanded'
                      and {org_team_key_sql} = {selected_team_key_sql}
                )
                select p.id,
                       p.handle,
                       p.real_name as "realName",
                       tm.role,
                       tm.is_starter as "isStarter",
                       g.code as "gameCode",
                       g.name as "gameName",
                       g.short_name as "gameShortName",
                       org_team.name as "teamName",
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
                join org_teams org_team on org_team.id = tm.team_id
                join players p on p.id = tm.player_id
                left join games g on g.id = coalesce(tm.game_id, p.primary_game_id, org_team.primary_game_id)
                where tm.active_to is null
                order by coalesce((g.metadata ->> 'priority')::int, 999),
                         g.name nulls last,
                         tm.is_starter desc nulls last,
                         p.handle
                """,
                (team_id,),
            )
            roster = cursor.fetchall()
    payload = dict(team)
    payload["roster"] = roster
    payload["participatingGames"] = get_team_games(team_id)
    return to_jsonable(payload)


def get_tournament(tournament_id: str) -> dict[str, object] | None:
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                select t.id,
                       case
                           when t.name in ('Playoffs', 'Group Stage', 'Group A', 'Group B', 'Group C', 'Group D', 'Regular Season', 'Play-In', 'Main Stage', 'Stage 2')
                             and l.name is not null then l.name || ' · ' || t.name
                           else t.name
                       end as name,
                       t.slug, t.format,
                       t.prize_pool as "prizePool",
                       t.starts_at as "startsAt",
                       t.ends_at as "endsAt",
                       t.status,
                       t.metadata,
                       g.name as "gameName",
                       g.code as "gameCode",
                       g.short_name as "gameShortName",
                       ({GAME_IMAGE_SQL}) #>> '{{variants,sm,url}}' as "gameImageUrl",
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
                           nullif(t.metadata #>> '{media,logo_url}', ''),
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


def list_tournaments(limit: int = 80, status: str | None = None, featured: bool = False) -> list[dict[str, object]]:
    """Return tournament catalog rows for the iOS tournaments center.

    PandaScore often stores a tournament stage as the tournament name
    ("Playoffs", "Group Stage"). For the app catalog we expose a richer display
    name using the league name while still preserving leagueName/seriesName.
    """
    where = ["true"]
    params: list[object] = []

    if status:
        where.append("t.status = %s")
        params.append(status)
    if featured:
        where.append("coalesce((t.metadata #>> '{featured}')::boolean, false) = true")

    params.append(limit)
    sql = f"""
        select
            t.id,
            case
                when t.name in ('Playoffs', 'Group Stage', 'Group A', 'Group B', 'Group C', 'Group D', 'Regular Season', 'Play-In', 'Main Stage', 'Stage 2')
                  and l.name is not null then l.name || ' · ' || t.name
                else t.name
            end as name,
            t.slug,
            t.format,
            t.prize_pool as "prizePool",
            t.starts_at as "startsAt",
            t.ends_at as "endsAt",
            t.status,
            t.metadata,
            g.code as "gameCode",
            g.name as "gameName",
            g.short_name as "gameShortName",
            ({GAME_IMAGE_SQL}) #>> '{{variants,sm,url}}' as "gameImageUrl",
            l.name as "leagueName",
            s.name as "seriesName",
            coalesce(
                ({_entity_image_sql('tournament', 't', 'logo')}) #>> '{{variants,sm,url}}',
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
                nullif(t.metadata #>> '{{media,logo_url}}', ''),
                nullif(l.metadata #>> '{{pandascore,image_url}}', '')
            ) as "imageUrl",
            coalesce((t.metadata #>> '{{featured}}')::boolean, false) as "isFeatured",
            nullif(t.metadata #>> '{{tier}}', '') as tier,
            nullif(t.metadata #>> '{{location}}', '') as location,
            nullif(t.metadata #>> '{{prizeNote}}', '') as "prizeNote",
            nullif(t.metadata #>> '{{gameSummary}}', '') as "gameSummary",
            coalesce(
                (
                    select count(*)
                    from matches m
                    where m.tournament_id = t.id
                ),
                0
            ) as "matchCount",
            coalesce(
                (
                    select count(*)
                    from tournament_participants tp
                    where tp.tournament_id = t.id
                ),
                0
            ) as "participantCount"
        from tournaments t
        left join games g on g.id = t.game_id
        left join leagues l on l.id = t.league_id
        left join series s on s.id = t.series_id
        where {' and '.join(where)}
        order by
            coalesce((t.metadata #>> '{{featured}}')::boolean, false) desc,
            case t.status
                when 'running' then 0
                when 'scheduled' then 1
                when 'postponed' then 2
                when 'completed' then 3
                else 4
            end,
            coalesce((t.metadata #>> '{{displayOrder}}')::int, 9999),
            t.starts_at asc nulls last,
            t.updated_at desc
        limit %s
    """
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(sql, params)
            return to_jsonable(cursor.fetchall())


def create_user_account(email: str, hashed_password: str) -> dict[str, object] | None:
    with connect() as connection:
        with connection.cursor() as cursor:
            # Check if user already exists
            cursor.execute("SELECT id FROM app_users WHERE email = %s", (email,))
            if cursor.fetchone():
                return None
            
            cursor.execute(
                """
                INSERT INTO app_users (email, hashed_password, display_name)
                VALUES (%s, %s, %s)
                RETURNING id, email, display_name, locale, timezone, created_at, updated_at
                """,
                (email, hashed_password, email.split("@")[0])
            )
            user = cursor.fetchone()
            if user:
                # Create default user preferences
                cursor.execute(
                    """
                    INSERT INTO user_preferences (user_id)
                    VALUES (%s)
                    ON CONFLICT (user_id) DO NOTHING
                    """,
                    (user["id"],)
                )
                connection.commit()
                return to_jsonable(dict(user))
    return None


def get_user_account_by_email(email: str) -> dict[str, object] | None:
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, email, hashed_password, display_name, locale, timezone, created_at, updated_at
                FROM app_users
                WHERE email = %s
                """,
                (email,)
            )
            user = cursor.fetchone()
            if user:
                return to_jsonable(dict(user))
    return None


def get_user_account_by_id(user_id: str) -> dict[str, object] | None:
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, email, display_name, locale, timezone, created_at, updated_at
                FROM app_users
                WHERE id = %s
                """,
                (user_id,)
            )
            user = cursor.fetchone()
            if user:
                return to_jsonable(dict(user))
    return None


def delete_user_account(user_id: str) -> bool:
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute("DELETE FROM app_users WHERE id = %s RETURNING id", (user_id,))
            deleted = cursor.fetchone()
            connection.commit()
            return deleted is not None


def get_user_preferences(user_id: str) -> dict[str, object] | None:
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT language, calendar_preference as "calendarPreference",
                       saudi_fan_mode as "saudiFanMode", notifications_enabled as "notificationsEnabled",
                       notif_match_start as "notifMatchStart", notif_score_change as "notifScoreChange",
                       notif_match_end as "notifMatchEnd", notif_roster_change as "notifRosterChange",
                       notif_stream_live as "notifStreamLive", notif_fantasy_remind as "notifFantasyRemind",
                       quiet_hours as "quietHours", metadata
                FROM user_preferences
                WHERE user_id = %s
                """,
                (user_id,)
            )
            prefs = cursor.fetchone()
            if prefs:
                return to_jsonable(dict(prefs))
    return None


def update_user_preferences(user_id: str, prefs_dict: dict) -> dict[str, object] | None:
    mapping = {
        "language": "language",
        "calendarPreference": "calendar_preference",
        "saudiFanMode": "saudi_fan_mode",
        "notificationsEnabled": "notifications_enabled",
        "notifMatchStart": "notif_match_start",
        "notifScoreChange": "notif_score_change",
        "notifMatchEnd": "notif_match_end",
        "notifRosterChange": "notif_roster_change",
        "notifStreamLive": "notif_stream_live",
        "notifFantasyRemind": "notif_fantasy_remind",
    }
    
    set_clauses = []
    params = []
    for api_key, db_col in mapping.items():
        if api_key in prefs_dict:
            set_clauses.append(f"{db_col} = %s")
            params.append(prefs_dict[api_key])
            
    if not set_clauses:
        return get_user_preferences(user_id)
        
    set_clauses.append("updated_at = now()")
    sql = f"""
    UPDATE user_preferences
    SET {', '.join(set_clauses)}
    WHERE user_id = %s
    """
    params.append(user_id)
    
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(sql, tuple(params))
            connection.commit()
            
    return get_user_preferences(user_id)


def get_user_follows(user_id: str) -> list[dict[str, object]]:
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT 
                    uf.entity_type as "entityType", 
                    uf.entity_id as "entityId", 
                    uf.notification_level as "notificationLevel",
                    COALESCE(g.code, t.name) as "entityName"
                FROM user_follows uf
                LEFT JOIN games g ON uf.entity_type = 'game' AND uf.entity_id = g.id
                LEFT JOIN teams t ON uf.entity_type = 'team' AND uf.entity_id = t.id
                WHERE uf.user_id = %s
                """,
                (user_id,)
            )
            return to_jsonable(cursor.fetchall())


def _resolve_entity_uuid(entity_type: str, entity_id: str) -> str | None:
    import uuid
    # 1. If it's already a valid UUID, return it
    try:
        uuid.UUID(str(entity_id))
        return entity_id
    except ValueError:
        pass

    # 2. Otherwise, look it up in the database
    with connect() as connection:
        with connection.cursor() as cursor:
            if entity_type == 'game':
                # Map some common client-side codes/names to db codes
                lookup_codes = [entity_id.lower()]
                if entity_id == 'cs-go':
                    lookup_codes.append('cs2')
                elif entity_id == 'league-of-legends':
                    lookup_codes.append('lol')
                elif entity_id == 'rainbow-6-siege':
                    lookup_codes.append('rainbow-six-siege')
                elif entity_id == 'ea-sports-fc':
                    lookup_codes.append('ea-fc')
                elif entity_id == 'call-of-duty':
                    lookup_codes.append('cod-mw')
                elif entity_id == 'king-of-glory':
                    lookup_codes.append('kog')

                cursor.execute(
                    """
                    SELECT id FROM games 
                    WHERE code = ANY(%s) OR name ILIKE %s OR short_name ILIKE %s
                    LIMIT 1
                    """,
                    (lookup_codes, entity_id, entity_id)
                )
                row = cursor.fetchone()
                if row:
                    return str(row['id'])

            elif entity_type == 'team':
                # Remove common prefixes/suffixes for clean comparison
                clean_name = entity_id.replace(" Esports", "").replace(" esports", "").strip()
                cursor.execute(
                    """
                    SELECT id FROM teams 
                    WHERE name ILIKE %s OR name ILIKE %s OR short_name ILIKE %s OR slug = %s
                    LIMIT 1
                    """,
                    (entity_id, f"%{clean_name}%", entity_id, entity_id.lower().replace(" ", "-"))
                )
                row = cursor.fetchone()
                if row:
                    return str(row['id'])
                
    return None


def follow_entity(user_id: str, entity_type: str, entity_id: str, notification_level: str = "normal") -> bool:
    if entity_type not in ('game', 'team', 'player', 'league', 'series', 'tournament', 'match'):
        return False
    
    resolved_id = _resolve_entity_uuid(entity_type, entity_id)
    if not resolved_id:
        print(f"Failed to resolve {entity_type} entity_id: {entity_id}")
        return False
        
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO user_follows (user_id, entity_type, entity_id, notification_level)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (user_id, entity_type, entity_id) 
                DO UPDATE SET notification_level = EXCLUDED.notification_level
                RETURNING id
                """,
                (user_id, entity_type, resolved_id, notification_level)
            )
            res = cursor.fetchone()
            connection.commit()
            return res is not None


def unfollow_entity(user_id: str, entity_type: str, entity_id: str) -> bool:
    resolved_id = _resolve_entity_uuid(entity_type, entity_id)
    if not resolved_id:
        print(f"Failed to resolve {entity_type} entity_id to unfollow: {entity_id}")
        return False

    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                DELETE FROM user_follows
                WHERE user_id = %s AND entity_type = %s AND entity_id = %s
                RETURNING id
                """,
                (user_id, entity_type, resolved_id)
            )
            res = cursor.fetchone()
            connection.commit()
            return res is not None


def list_trending_tournaments(limit: int = 10) -> list[dict[str, object]]:
    """Get active and upcoming featured tournaments for the Discover page."""
    sql = f"""
        select
            t.id,
            t.name,
            t.status,
            t.starts_at as "startsAt",
            t.ends_at as "endsAt",
            g.code as "gameCode",
            g.name as "gameName",
            g.short_name as "gameShortName",
            ({_entity_image_sql('tournament', 't', 'logo')}) as image
        from tournaments t
        left join games g on g.id = t.game_id
        where t.status in ('running', 'scheduled')
          and (t.ends_at is null or t.ends_at >= now())
        order by case when t.status = 'running' then 0 else 1 end, t.starts_at asc
        limit %s
    """
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(sql, (limit,))
            rows = cursor.fetchall()
            return to_jsonable(rows)


def discover_search(query: str, limit: int = 15) -> dict[str, list[dict[str, object]]]:
    """Search teams, tournaments, and players matching the text query."""
    q_pattern = f"%{query}%"
    
    # 1. Search Teams
    teams_sql = f"""
        select
            t.id,
            t.name,
            t.slug,
            ({_entity_image_sql('team', 't', 'logo')}) #>> '{{variants,sm,url}}' as "imageUrl",
            g.code as "gameCode",
            g.name as "gameName",
            ({_entity_image_sql('team', 't', 'logo')}) as image
        from teams t
        left join games g on g.id = t.primary_game_id
        where t.name ilike %s or t.slug::text ilike %s
        order by t.name asc
        limit %s
    """
    
    # 2. Search Tournaments
    tournaments_sql = f"""
        select
            t.id,
            t.name,
            t.status,
            t.starts_at as "startsAt",
            t.ends_at as "endsAt",
            ({_entity_image_sql('tournament', 't', 'logo')}) #>> '{{variants,sm,url}}' as "imageUrl",
            g.code as "gameCode",
            g.name as "gameName",
            ({_entity_image_sql('tournament', 't', 'logo')}) as image
        from tournaments t
        left join games g on g.id = t.game_id
        where t.name ilike %s or t.slug::text ilike %s
        order by t.starts_at desc
        limit %s
    """
    
    # 3. Search Players
    players_sql = f"""
        select
            p.id,
            p.handle,
            p.real_name as "realName",
            p.slug,
            p.country_code as "countryCode",
            ({_entity_image_sql('player', 'p', 'portrait')}) #>> '{{variants,sm,url}}' as "imageUrl",
            g.code as "gameCode",
            g.name as "gameName",
            ({_entity_image_sql('player', 'p', 'portrait')}) as image
        from players p
        left join games g on g.id = p.primary_game_id
        where p.handle ilike %s or p.real_name ilike %s or p.slug::text ilike %s
        order by p.handle asc
        limit %s
    """
    
    with connect() as connection:
        with connection.cursor() as cursor:
            # Search Teams
            cursor.execute(teams_sql, (q_pattern, q_pattern, limit))
            teams = to_jsonable(cursor.fetchall())
            
            # Search Tournaments
            cursor.execute(tournaments_sql, (q_pattern, q_pattern, limit))
            tournaments = to_jsonable(cursor.fetchall())
            
            # Search Players
            cursor.execute(players_sql, (q_pattern, q_pattern, q_pattern, limit))
            players = to_jsonable(cursor.fetchall())
            
            return {
                "teams": teams,
                "tournaments": tournaments,
                "players": players
            }


def get_game_hub_details(game_code: str) -> dict[str, object] | None:
    """Get matches, teams, and tournaments for a specific game hub."""
    # 1. Get Game
    game_sql = f"""
        select
            g.id,
            g.code,
            g.name,
            g.short_name as "shortName",
            ({GAME_IMAGE_SQL}) as image
        from games g
        where g.code = %s
    """
    
    with connect() as connection:
        with connection.cursor() as cursor:
            cursor.execute(game_sql, (game_code,))
            game = cursor.fetchone()
            if not game:
                return None
            game = to_jsonable(game)
            game_uuid = game["id"]
            
            # 2. Get matches for this game (live or upcoming)
            matches_sql = f"""
                select
                    m.id,
                    m.name,
                    m.status,
                    m.scheduled_at as "scheduledAt",
                    m.begin_at as "beginAt",
                    m.end_at as "endAt",
                    m.best_of as "bestOf"
                from matches m
                where m.game_id = %s
                  and m.status in ('live', 'scheduled')
                order by case when m.status = 'live' then 0 else 1 end, m.scheduled_at asc
                limit 10
            """
            cursor.execute(matches_sql, (game_uuid,))
            matches = to_jsonable(cursor.fetchall())
            
            # 3. Get trending teams for this game
            teams_sql = f"""
                select
                    t.id,
                    t.name,
                    t.slug,
                    ({_entity_image_sql('team', 't', 'logo')}) as image
                from teams t
                where t.primary_game_id = %s
                order by t.name asc
                limit 10
            """
            cursor.execute(teams_sql, (game_uuid,))
            teams = to_jsonable(cursor.fetchall())
            
            # 4. Get active tournaments for this game
            tournaments_sql = f"""
                select
                    t.id,
                    t.name,
                    t.status,
                    t.starts_at as "startsAt",
                    t.ends_at as "endsAt",
                    ({_entity_image_sql('tournament', 't', 'logo')}) as image
                from tournaments t
                where t.game_id = %s
                  and t.status in ('running', 'scheduled')
                order by case when t.status = 'running' then 0 else 1 end, t.starts_at asc
                limit 10
            """
            cursor.execute(tournaments_sql, (game_uuid,))
            tournaments = to_jsonable(cursor.fetchall())
            
            return {
                "game": game,
                "matches": matches,
                "teams": teams,
                "tournaments": tournaments
            }
