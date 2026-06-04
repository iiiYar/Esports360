"""
Steam Web API Engine — CS2 match data via official Steam Web API

Uses the free Steam Web API key to fetch CS2 tournament news and match data.
Data flows through provider_entity_map for deduplication.
"""

import asyncio
import time
from typing import Any
from uuid import UUID

import httpx
from psycopg import Connection
from psycopg.types.json import Jsonb

from esports360.database import connect
from esports360.storage import find_entity_by_external_id, remember_external_id

STEAM_API_BASE = "https://api.steampowered.com"


class SteamWebAPIEngine:
    def __init__(self, provider_id: UUID, api_key: str, game_id: UUID, poll_interval: int = 30) -> None:
        self.provider_id = provider_id
        self.api_key = api_key
        self.game_id = game_id
        self.poll_interval = poll_interval
        self._client = httpx.AsyncClient(timeout=httpx.Timeout(20.0))

    async def run(self) -> None:
        print(f"Steam Web API Engine: starting, interval={self.poll_interval}s", flush=True)
        backoff = self.poll_interval

        while True:
            t0 = time.monotonic()
            try:
                count = await self._poll()
                elapsed = time.monotonic() - t0
                if count:
                    print(f"Steam Web API Engine: synced {count} items in {elapsed:.1f}s", flush=True)
                backoff = self.poll_interval
            except Exception as exc:
                err = str(exc)[:150]
                print(f"Steam Web API Engine: error: {err}", flush=True)
                backoff = min(backoff * 2, 300)
            await asyncio.sleep(backoff)

    async def _poll(self) -> int:
        matches = await self._fetch_tournament_news()
        if not matches:
            return 0
        with connect() as conn:
            count = self._upsert_news_matches(conn, matches)
            conn.commit()
        return count

    async def _fetch_tournament_news(self) -> list[dict[str, Any]]:
        """Fetch CS2 tournament news from Steam."""
        matches: list[dict[str, Any]] = []
        try:
            url = (
                f"{STEAM_API_BASE}/ISteamNews/GetNewsForApp/v2/"
                f"?appid=730&count=15&maxlength=300&format=json&feeds=steam_community_announcements"
            )
            resp = await self._client.get(url)
            if resp.status_code != 200:
                print(f"Steam Web API Engine: news HTTP {resp.status_code}", flush=True)
                return matches

            data = resp.json()
            for item in data.get("appnews", {}).get("newsitems", []):
                title = item.get("title", "")
                # Filter for tournament/event related news
                tourney_kw = [
                    "major", "tournament", "championship", "blast", "iem", "esl",
                    "pro league", "rmr", "qualifier", "pgl", "dreamhack",
                    "copenhagen", "cologne", "katowice", "rio",
                    "group stage", "playoffs", "final", "grand final",
                    "open qualifier", "closed qualifier", "showmatch",
                    "esports", "competitive", "season"
                ]
                if not any(kw in title.lower() for kw in tourney_kw):
                    continue

                ext_id = f"steam-news-{item.get('gid', '')}"
                matches.append({
                    "external_id": ext_id,
                    "name": title,
                    "status": "scheduled",
                    "url": item.get("url", ""),
                    "external_data": {
                        "source": "steam_news",
                        "gid": item.get("gid"),
                        "feed_type": item.get("feed_type"),
                        "date": item.get("date"),
                    },
                })

            if matches:
                print(f"Steam Web API Engine: {len(matches)} tournament news found", flush=True)
        except Exception as e:
            print(f"Steam Web API Engine: news fetch failed: {e}", flush=True)
        return matches

    def _upsert_news_matches(self, conn: Connection, items: list[dict[str, Any]]) -> int:
        count = 0
        with conn.cursor() as cur:
            for item in items:
                try:
                    ext_id = item["external_id"]
                    # Check if we already have this via provider_entity_map
                    existing = find_entity_by_external_id(
                        conn,
                        provider_id=self.provider_id,
                        entity_type="match",
                        external_id=ext_id,
                    )
                    if existing:
                        continue  # Already synced

                    # Build slug: clean title, lowercase, dashes
                    slug = item["name"].lower()
                    slug = "".join(c if c.isalnum() or c == " " else " " for c in slug)
                    slug = "-".join(slug.split())[:200]

                    # Insert match
                    cur.execute(
                        """
                        INSERT INTO matches (
                            game_id, name, slug, status, metadata, created_at, updated_at
                        )
                        VALUES (%s, %s, %s, %s, %s, now(), now())
                        ON CONFLICT (slug) DO UPDATE SET
                            metadata = EXCLUDED.metadata,
                            updated_at = now()
                        RETURNING id
                        """,
                        (
                            self.game_id,
                            item["name"],
                            slug,
                            item.get("status", "scheduled"),
                            Jsonb(item.get("external_data", {})),
                        ),
                    )
                    row = cur.fetchone()
                    if row:
                        match_id = row["id"]
                        # Register in provider_entity_map
                        remember_external_id(
                            conn,
                            provider_id=self.provider_id,
                            entity_type="match",
                            entity_id=match_id,
                            external_id=ext_id,
                        )
                        count += 1
                except Exception as exc:
                    print(f"Steam Web API Engine: upsert error: {exc}", flush=True)
        return count
