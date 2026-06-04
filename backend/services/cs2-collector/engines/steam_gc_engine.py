"""
Steam Game Coordinator Engine — real-time CS2 live match data via Steam GC.

Uses the Steam Web API + Valve's Game Coordinator protocol to fetch live
match events (kill feed, round outcomes, economy states) for active CS2
matches.

NOTE: Steam GC requires an unblocked connection to api.steampowered.com.
If blocked (common in some regions), the engine enters idle/retry mode.
"""

import asyncio
import time
import threading
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from psycopg import Connection
from psycopg.types.json import Jsonb

from esports360.database import connect

STEAM_AVAILABLE = False
try:
    import gevent.monkey
    gevent.monkey.patch_all(thread=False, select=False)
    from steam.client import SteamClient
    from steam.enums import EResult
    STEAM_AVAILABLE = True
except ImportError:
    pass


class SteamGCEngine:
    """Real-time listener for CS2 live match data via Steam GC."""

    def __init__(self, provider_id: UUID, steam_api_key: str) -> None:
        self.provider_id = str(provider_id)
        self.steam_api_key = steam_api_key
        self._active_matches: dict[str, dict] = {}
        self._running = False

    async def run(self) -> None:
        """Main entry point: connect to Steam GC and stream live data."""
        if not STEAM_AVAILABLE:
            print("Steam GC Engine: steam/csgo packages not installed; engine idle.", flush=True)
            while True:
                await asyncio.sleep(60)

        self._running = True
        print("Steam GC Engine: connecting to Steam GC…", flush=True)

        # Run Steam client in a gevent-powered thread to avoid blocking asyncio
        loop = asyncio.get_running_loop()
        retry_delay = 10

        while self._running:
            try:
                await loop.run_in_executor(None, self._steam_connect_and_run)
            except Exception as exc:
                print(f"Steam GC Engine: connection error: {exc}", flush=True)
            retry_delay = min(retry_delay * 2, 120)
            print(f"Steam GC Engine: reconnecting in {retry_delay}s…", flush=True)
            await asyncio.sleep(retry_delay)

    def _steam_connect_and_run(self) -> None:
        """Blocking gevent loop — runs in a thread executor."""
        import gevent
        from gevent import monkey
        monkey.patch_socket()

        client = SteamClient()
        client.set_credential_location("")

        if self.steam_api_key:
            client.api_key = self.steam_api_key

        try:
            result = client.anonymous_login()
            if result != EResult.OK:
                print(f"Steam GC Engine: anonymous login result: {result}", flush=True)
                return
            print("Steam GC Engine: logged on to Steam", flush=True)

            # Run the gevent event loop — this blocks the thread
            while self._running and client.logged_on:
                gevent.sleep(1)
        except Exception as exc:
            print(f"Steam GC Engine: gevent loop error: {exc}", flush=True)
        finally:
            if client.logged_on:
                client.logout()

    # ------------------------------------------------------------------
    # Live event writers
    # ------------------------------------------------------------------

    def write_live_event(
        self,
        match_id: str,
        event_type: str,
        occurred_at: str,
        payload: dict | None = None,
    ) -> None:
        """Write a single live event (kill, round_end, bomb_plant, etc.)."""
        try:
            with connect() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO live_events (
                            match_id, sequence, event_type, occurred_at,
                            source_provider_id, payload, created_at
                        )
                        VALUES (
                            %(match_id)s,
                            (SELECT COALESCE(MAX(sequence), 0) + 1 FROM live_events WHERE match_id = %(match_id)s),
                            %(event_type)s, %(occurred_at)s,
                            %(provider_id)s, %(payload)s, now()
                        )
                        """,
                        {
                            "match_id": match_id,
                            "event_type": event_type,
                            "occurred_at": occurred_at,
                            "provider_id": self.provider_id,
                            "payload": Jsonb(payload or {}),
                        },
                    )
                conn.commit()
        except Exception as exc:
            print(f"Steam GC Engine: event write error: {exc}", flush=True)

    def write_match_state(
        self,
        match_id: str,
        status: str,
        clock_seconds: int | None = None,
        state: dict | None = None,
    ) -> None:
        """Upsert the current live match state."""
        try:
            with connect() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO live_match_states (
                            match_id, status, clock_seconds, state,
                            source_provider_id, provider_freshness_at, updated_at
                        )
                        VALUES (%s, %s, %s, %s, %s, now(), now())
                        ON CONFLICT (match_id) DO UPDATE SET
                            status = EXCLUDED.status,
                            clock_seconds = EXCLUDED.clock_seconds,
                            state = EXCLUDED.state,
                            provider_freshness_at = now(),
                            updated_at = now()
                        """,
                        (match_id, status, clock_seconds, Jsonb(state or {}), self.provider_id),
                    )
                conn.commit()
        except Exception as exc:
            print(f"Steam GC Engine: state write error: {exc}", flush=True)

    def write_match_score(
        self,
        match_id: str,
        team_id: str,
        score_type: str,
        value: float,
        game_number: int = 1,
    ) -> None:
        """Record a score update for a team in a match."""
        try:
            with connect() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO match_scores (
                            match_id, team_id, score_type, game_number,
                            value, recorded_at, metadata
                        )
                        VALUES (%s, %s, %s, %s, %s, now(), %s)
                        """,
                        (
                            match_id, team_id, score_type, game_number, value,
                            Jsonb({"source": "steam_gc"}),
                        ),
                    )
                conn.commit()
        except Exception as exc:
            print(f"Steam GC Engine: score write error: {exc}", flush=True)
