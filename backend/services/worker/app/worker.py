import asyncio
import signal
import time
from datetime import datetime, timezone

from apscheduler.schedulers.background import BackgroundScheduler

from esports360.config import get_settings
from esports360.database import connect
from esports360.media_pipeline import backfill_game_logos, backfill_player_images, backfill_team_logos
from esports360.normalizers import (
    normalize_pandascore_matches,
    normalize_pandascore_team_rosters,
    normalize_pandascore_videogames,
    _match_status,
)
from esports360.storage import get_provider_id
from esports360.pandascore import PandaScoreProvider


running = True
scheduler = None


DEFAULT_PRIORITY_PANDASCORE_TEAM_IDS = (
    "133868",  # Team Falcons
    "138068",  # Twisted Minds
    "130861",  # NASR Esports
    "129571",  # Sandrock Gaming
    "126061",  # T1
    "128538",  # G2 Esports
    "136396",  # Team Liquid
    "135125",  # Fnatic ONIC
    "137057",  # Natus Vincere
    "135679",  # Team Vitality
)


def stop(_: int, __: object) -> None:
    global running
    running = False


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)


async def sync_pandascore_videogames() -> int:
    settings = get_settings()
    provider = PandaScoreProvider(settings.pandascore_token, settings.pandascore_base_url)
    games = await provider.videogames()
    with connect() as connection:
        count = normalize_pandascore_videogames(connection, games)
        connection.commit()
    return count


async def reconcile_disappeared_matches(provider: PandaScoreProvider, live_external_ids: set[str]) -> int:
    """Active Reconciliation: detect matches our DB thinks are 'live' but
    PandaScore no longer reports in /matches/running.

    For each disappeared match, fetch its real status from PandaScore and
    update our DB immediately — no more waiting 3 hours for the reaper.
    """
    reconciled = 0
    try:
        with connect() as connection:
            provider_id = get_provider_id(connection, "pandascore")
            with connection.cursor() as cursor:
                cursor.execute("""
                    SELECT pem.external_id, m.id, m.name
                    FROM matches m
                    JOIN provider_entity_map pem ON pem.entity_id = m.id
                    WHERE m.status = 'live'
                      AND pem.provider_id = %s
                      AND pem.entity_type = 'match'
                """, (provider_id,))
                db_live_matches = cursor.fetchall()

            for row in db_live_matches:
                ext_id = str(row["external_id"])
                if ext_id in live_external_ids:
                    continue  # Still live — skip

                # This match vanished from /running → it probably ended
                try:
                    details = await provider.match_details(ext_id)
                    real_status = _match_status(details.get("status"))
                except Exception:
                    real_status = "completed"  # Safe fallback

                if real_status != "live":
                    with connection.cursor() as cursor:
                        cursor.execute(
                            "UPDATE matches SET status = %s, updated_at = now() WHERE id = %s",
                            (real_status, row["id"]),
                        )
                        # Also clean up live_match_states
                        cursor.execute(
                            "DELETE FROM live_match_states WHERE match_id = %s",
                            (row["id"],),
                        )
                    reconciled += 1
                    print(
                        f"reconcile: {row['name']} → {real_status} (was live, vanished from /running)",
                        flush=True,
                    )

            connection.commit()
    except Exception as exc:
        print(f"reconcile: error: {exc}", flush=True)
    return reconciled


async def sync_pandascore_matches(feed_type: str) -> int:
    global scheduler
    settings = get_settings()
    provider = PandaScoreProvider(settings.pandascore_token, settings.pandascore_base_url)
    
    if feed_type == "pandascore_live_matches":
        matches = await provider.running_matches()
        count = len(matches)
        
        # --- Active Reconciliation: fix matches that ended ---
        live_external_ids = {str(m.get("id")) for m in matches if m.get("id") is not None}
        try:
            fixed = await reconcile_disappeared_matches(provider, live_external_ids)
            if fixed:
                print(f"reconcile: fixed {fixed} matches that vanished from /running", flush=True)
        except Exception as e:
            print(f"reconcile: error: {e}", flush=True)
        
        # --- Smart Dynamic Scaling & API Credit Protection ---
        if scheduler:
            try:
                job = scheduler.get_job("pandascore_live_matches")
                if job:
                    current_trigger_interval = getattr(job.trigger, "interval", None)
                    current_seconds = getattr(current_trigger_interval, "seconds", None)
                    
                    if count > 0:
                        fast_interval = 20
                        if current_seconds != fast_interval:
                            print(f"Dynamic Scale: Live matches detected ({count}). Boosting live sync to every {fast_interval}s.", flush=True)
                            scheduler.reschedule_job("pandascore_live_matches", trigger="interval", seconds=fast_interval)
                    else:
                        slow_interval = 300
                        if current_seconds != slow_interval:
                            print(f"Dynamic Scale: No active live matches. Backing off live sync to every {slow_interval}s to save API credits.", flush=True)
                            scheduler.reschedule_job("pandascore_live_matches", trigger="interval", seconds=slow_interval)
            except Exception as e:
                print(f"Dynamic Scale Error: {e}", flush=True)
                
    elif feed_type == "pandascore_upcoming_matches":
        matches = await provider.upcoming_matches(settings.pandascore_upcoming_days)
    else:
        # Today's matches
        matches = await provider.today_matches()
        
        # Today's sync check: if a match has status == "running" or starts within 10 minutes, boost live sync immediately!
        if scheduler:
            try:
                has_live_or_soon = False
                now_dt = datetime.now(timezone.utc)
                for m in matches:
                    if m.get("status") == "running":
                        has_live_or_soon = True
                        break
                    scheduled_str = m.get("scheduled_at")
                    if scheduled_str:
                        scheduled_dt = datetime.fromisoformat(scheduled_str.replace("Z", "+00:00"))
                        time_diff = (scheduled_dt - now_dt).total_seconds()
                        # Starts in less than 10 minutes or started less than 2 hours ago
                        if -7200 < time_diff < 600:
                            has_live_or_soon = True
                            break
                            
                if has_live_or_soon:
                    job = scheduler.get_job("pandascore_live_matches")
                    if job:
                        current_trigger_interval = getattr(job.trigger, "interval", None)
                        current_seconds = getattr(current_trigger_interval, "seconds", None)
                        if current_seconds != 20:
                            print("Dynamic Scale: Today's feed detected live or imminent match! Boosting live sync frequency to 20s.", flush=True)
                            scheduler.reschedule_job("pandascore_live_matches", trigger="interval", seconds=20)
            except Exception as e:
                print(f"Dynamic Scale Check Error: {e}", flush=True)
                
    with connect() as connection:
        count = normalize_pandascore_matches(connection, matches, feed_type)
        connection.commit()
    return count



def priority_team_ids() -> list[str]:
    settings = get_settings()
    configured = [
        item.strip()
        for item in settings.pandascore_priority_team_ids.replace("\n", ",").split(",")
        if item.strip()
    ]
    values = configured or list(DEFAULT_PRIORITY_PANDASCORE_TEAM_IDS)
    return values[: settings.pandascore_roster_team_limit]


async def sync_pandascore_priority_rosters() -> int:
    settings = get_settings()
    provider = PandaScoreProvider(settings.pandascore_token, settings.pandascore_base_url)
    teams = []
    for team_id in priority_team_ids():
        try:
            teams.append(await provider.team(team_id))
        except Exception as error:  # noqa: BLE001 - one stale team id should not stop the roster sync.
            print(f"pandascore_team_rosters: failed team={team_id}: {error}", flush=True)

    with connect() as connection:
        count = normalize_pandascore_team_rosters(connection, teams)
        connection.commit()
    return count


def reap_stale_matches() -> None:
    """Fix matches stuck in 'live' status after the provider stopped reporting them.

    PandaScore's /matches/running only returns currently-live matches.
    When a match ends it simply disappears from the response, leaving
    our DB row in status='live' forever.  This job detects matches
    that haven't been updated in >3 hours and transitions them to
    'completed' (if a winner exists) or 'unknown'.
    """
    try:
        with connect() as connection:
            with connection.cursor() as cursor:
                # Promote stale matches that have a declared winner
                cursor.execute("""
                    UPDATE matches SET status = 'completed', updated_at = now()
                    WHERE status = 'live'
                      AND updated_at < NOW() - INTERVAL '3 hours'
                      AND winner_team_id IS NOT NULL
                """)
                completed_count = cursor.rowcount

                # Mark the rest as unknown
                cursor.execute("""
                    UPDATE matches SET status = 'unknown', updated_at = now()
                    WHERE status = 'live'
                      AND updated_at < NOW() - INTERVAL '3 hours'
                      AND winner_team_id IS NULL
                """)
                unknown_count = cursor.rowcount

                # Remove orphaned live_match_states for non-live matches
                cursor.execute("""
                    DELETE FROM live_match_states
                    WHERE match_id IN (
                        SELECT id FROM matches WHERE status NOT IN ('live')
                    )
                """)
                cleaned_states = cursor.rowcount

            connection.commit()

        total = completed_count + unknown_count
        if total:
            print(
                f"stale_reaper: fixed {completed_count} → completed, "
                f"{unknown_count} → unknown, cleaned {cleaned_states} live_states",
                flush=True,
            )
    except Exception as error:  # noqa: BLE001
        print(f"stale_reaper: failed: {error}", flush=True)


def run_job(name: str, coro: object) -> None:
    try:
        count = asyncio.run(coro)
        print(f"{name}: synced {count} records", flush=True)
    except Exception as error:  # noqa: BLE001 - worker should keep running after provider failures.
        print(f"{name}: failed: {error}", flush=True)


def run_image_backfill() -> None:
    try:
        with connect() as connection:
            team_result = backfill_team_logos(connection)
            game_result = backfill_game_logos(connection)
            player_result = backfill_player_images(connection)
            connection.commit()
        print(
            "image_backfill: "
            f"team_logos={team_result.processed}/{team_result.succeeded}/{team_result.skipped}/{team_result.failed} "
            f"game_logos={game_result.processed}/{game_result.succeeded}/{game_result.skipped}/{game_result.failed} "
            f"player_portraits={player_result.processed}/{player_result.succeeded}/{player_result.skipped}/{player_result.failed}",
            flush=True,
        )
    except Exception as error:  # noqa: BLE001 - worker should keep running after media failures.
        print(f"image_backfill_team_logos: failed: {error}", flush=True)


def main() -> None:
    global scheduler
    settings = get_settings()
    scheduler = BackgroundScheduler(timezone=settings.app_timezone)

    if not settings.pandascore_sync_enabled:
        print("Esports360 worker ready. PandaScore sync is disabled.", flush=True)
    elif not settings.pandascore_token:
        print("Esports360 worker ready. PANDASCORE_TOKEN is missing; sync is disabled.", flush=True)
    else:
        scheduler.add_job(
            lambda: run_job("pandascore_videogames", sync_pandascore_videogames()),
            "interval",
            hours=24,
            id="pandascore_videogames",
            replace_existing=True,
        )
        scheduler.add_job(
            lambda: run_job("pandascore_today_matches", sync_pandascore_matches("pandascore_today_matches")),
            "interval",
            seconds=settings.pandascore_today_interval_seconds,
            id="pandascore_today_matches",
            replace_existing=True,
        )
        scheduler.add_job(
            lambda: run_job("pandascore_live_matches", sync_pandascore_matches("pandascore_live_matches")),
            "interval",
            seconds=settings.pandascore_live_interval_seconds,
            id="pandascore_live_matches",
            replace_existing=True,
        )
        scheduler.add_job(
            lambda: run_job("pandascore_upcoming_matches", sync_pandascore_matches("pandascore_upcoming_matches")),
            "interval",
            seconds=settings.pandascore_upcoming_interval_seconds,
            id="pandascore_upcoming_matches",
            replace_existing=True,
        )
        scheduler.add_job(
            lambda: run_job("pandascore_team_rosters", sync_pandascore_priority_rosters()),
            "interval",
            hours=settings.pandascore_roster_interval_hours,
            id="pandascore_team_rosters",
            replace_existing=True,
        )
        scheduler.add_job(
            run_image_backfill,
            "interval",
            hours=settings.image_backfill_interval_hours,
            id="image_backfill_team_logos",
            replace_existing=True,
        )

    # --- Stale match reaper always runs, even without PandaScore ---
    scheduler.add_job(
        reap_stale_matches,
        "interval",
        minutes=5,
        id="stale_match_reaper",
        replace_existing=True,
    )

    scheduler.start()
    print("Esports360 worker ready. Stale reaper enabled.", flush=True)

    if settings.pandascore_sync_enabled and settings.pandascore_token:
        print("PandaScore polling jobs are active.", flush=True)
        if settings.pandascore_sync_on_start:
            run_job("pandascore_videogames", sync_pandascore_videogames())
            run_job("pandascore_today_matches", sync_pandascore_matches("pandascore_today_matches"))
            run_job("pandascore_live_matches", sync_pandascore_matches("pandascore_live_matches"))
            run_job("pandascore_upcoming_matches", sync_pandascore_matches("pandascore_upcoming_matches"))
            run_job("pandascore_team_rosters", sync_pandascore_priority_rosters())
        if settings.image_backfill_on_start:
            run_image_backfill()

    # Run stale reaper once immediately on startup
    reap_stale_matches()

    while running:
        time.sleep(30)
    if scheduler.running:
        scheduler.shutdown(wait=False)
    print("Esports360 worker stopped.", flush=True)


if __name__ == "__main__":
    main()
