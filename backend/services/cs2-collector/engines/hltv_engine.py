"""
HLTV Engine — CS2 match data via curl_cffi TLS impersonation.

The collector is an optional CS2 enrichment source. It stores round-level map
scores only when the parsed values look like actual CS2 round scores, not
series map wins such as 1-0 or 1-1.
"""

import asyncio
import json
import time
from datetime import datetime
from typing import Any
from uuid import UUID
from zoneinfo import ZoneInfo

from bs4 import BeautifulSoup
from curl_cffi import requests
from psycopg import Connection
from psycopg.types.json import Jsonb

from esports360.database import connect
from esports360.config import get_settings

HLTV_MATCHES_URL = "https://www.hltv.org/matches"
HLTV_RESULTS_URL = "https://www.hltv.org/results"



class HLTvEngine:
    def __init__(self, provider_id: UUID, poll_interval: int = 30) -> None:
        self.provider_id = str(provider_id)
        self.poll_interval = poll_interval
        self.has_live_matches = False
        self._team_cache: dict[str, str] = {}

    async def run(self) -> None:
        """Main loop with curl_cffi TLS impersonation and dynamic polling."""
        print(f"HLTV Engine: starting curl_cffi TLS impersonation engine, {self.poll_interval}s default interval", flush=True)

        import random
        backoff = self.poll_interval
        while True:
            try:
                count = await self._poll_page()
                if count > 0:
                    print(f"HLTV Engine: synced {count} matches", flush=True)
                
                # Dynamic Polling Interval:
                if self.has_live_matches:
                    # Live matches active -> poll extremely fast (every 5 seconds) for real-time scores
                    sleep_time = 5
                    print("HLTV Engine: 🔴 Live matches active! Scaling interval down to 5s for real-time scores.", flush=True)
                    backoff = 5
                else:
                    # Idle state -> scale back to default interval with random jitter to bypass fingerprinting
                    jitter = random.randint(-15, 30) if self.poll_interval > 60 else 0
                    sleep_time = max(30, self.poll_interval + jitter)
                    print(f"HLTV Engine: 💤 No live matches active. Defaulting to {sleep_time}s interval.", flush=True)
                    backoff = self.poll_interval
            except Exception as exc:
                err = str(exc)[:150]
                print(f"HLTV Engine: error: {err}", flush=True)
                backoff = min(backoff * 2, 600)
                print(f"HLTV Engine: backoff {backoff}s", flush=True)
                sleep_time = backoff
            await asyncio.sleep(sleep_time)

    async def _fetch_url(self, url: str) -> str | None:
        """Fetch a URL using curl_cffi TLS impersonation."""
        loop = asyncio.get_running_loop()
        def fetch():
            try:
                resp = requests.get(
                    url,
                    impersonate="chrome124",
                    headers={
                        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
                        "Accept-Language": "en-US,en;q=0.9",
                        "Cache-Control": "max-age=0",
                        "Sec-Ch-Ua": '"Google Chrome";v="124", "Chromium";v="124", "Not-A.Brand";v="99"',
                        "Sec-Ch-Ua-Mobile": "?0",
                        "Sec-Ch-Ua-Platform": '"Windows"',
                        "Sec-Fetch-Dest": "document",
                        "Sec-Fetch-Mode": "navigate",
                        "Sec-Fetch-Site": "none",
                        "Sec-Fetch-User": "?1",
                        "Upgrade-Insecure-Requests": "1",
                        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
                    },
                    timeout=15
                )
                if resp.status_code < 400:
                    return resp.text
                print(f"HLTV Engine: HLTV detail fetcher failed for {url}, status code: {resp.status_code}", flush=True)
            except Exception as e:
                print(f"HLTV Engine: HLTV detail fetcher error for {url}: {e}", flush=True)
            return None

        return await loop.run_in_executor(None, fetch)

    async def _poll_page(self) -> int:
        """Fetch HLTV matches page using curl_cffi, parse, and upsert."""
        t0 = time.monotonic()

        html = await self._fetch_url(HLTV_MATCHES_URL)
        if not html:
            raise RuntimeError("Failed to fetch matches page")

        soup = BeautifulSoup(html, "lxml")
        matches_data = self._parse_html(soup)

        # Detect if any match is currently live
        self.has_live_matches = any(m.get("status") == "live" for m in matches_data)

        # Enrichment logic using the optional HLTV detail fetcher.
        # Live matches are the production path. When no live match exists, a
        # tiny completed-match probe proves the parser and DB write path without
        # faking live data.
        settings = get_settings()
        if settings.cs2_hltv_detail_enabled:
            live_matches = [m for m in matches_data if m.get("status") == "live"]
            due_upcoming_matches = [
                m for m in matches_data
                if m.get("status") == "upcoming"
                and self._is_due_for_detail_probe(m.get("scheduled_at"), settings.app_timezone)
            ][: settings.cs2_hltv_completed_detail_limit]
            detail_candidates = live_matches + due_upcoming_matches

            if not detail_candidates and settings.cs2_hltv_completed_detail_limit > 0:
                results_html = await self._fetch_url(HLTV_RESULTS_URL)
                if results_html:
                    result_matches = self._parse_results_html(BeautifulSoup(results_html, "lxml"))
                    detail_candidates = result_matches[: settings.cs2_hltv_completed_detail_limit]
                    existing_ids = {m.get("external_id") for m in matches_data}
                    for result in detail_candidates:
                        if result.get("external_id") not in existing_ids:
                            matches_data.append(result)
                            existing_ids.add(result.get("external_id"))
                    if detail_candidates:
                        print(
                            "HLTV Engine: HLTV detail fetcher / optional enrichment "
                            f"probing {len(detail_candidates)} completed matches for parser proof...",
                            flush=True,
                        )

            if detail_candidates:
                live_count = sum(1 for m in detail_candidates if m.get("status") == "live")
                print(
                    "HLTV Engine: HLTV detail fetcher / optional enrichment starting to fetch "
                    f"{len(detail_candidates)} matches ({live_count} live, {len(due_upcoming_matches)} due upcoming)...",
                    flush=True,
                )
                sem = asyncio.Semaphore(2)

                async def fetch_with_semaphore(m, s):
                    async with s:
                        url = m.get("detail_url")
                        if url:
                            print(f"HLTV Engine: HLTV detail fetcher / optional enrichment fetching details for {m.get('name')} (URL: {url})", flush=True)
                            await asyncio.sleep(0.5)  # Respectful delay
                            detail_html = await self._fetch_url(url)
                            if detail_html:
                                print(f"HLTV Engine: detail fetched successfully for {m.get('name')}", flush=True)
                                m["detail_html"] = detail_html

                tasks = [fetch_with_semaphore(m, sem) for m in detail_candidates]
                await asyncio.gather(*tasks)

        if not matches_data:
            print(f"HLTV Engine: page loaded but 0 matches parsed", flush=True)

        with connect() as conn:
            count = self._upsert_matches(conn, matches_data)
            conn.commit()

        elapsed = time.monotonic() - t0
        if count:
            print(f"HLTV Engine: {count} matches in {elapsed:.1f}s", flush=True)
        return count



    # ------------------------------------------------------------------
    # HTML parsing (same logic, now fed by real browser HTML)
    # ------------------------------------------------------------------

    @staticmethod
    def _match_elements(section) -> list[Any]:
        elements: list[Any] = []
        if section.get("data-match-id"):
            elements.append(section)
        elements.extend(section.select("[data-match-id]"))
        return elements

    @staticmethod
    def _is_due_for_detail_probe(scheduled_at: Any, app_timezone: str) -> bool:
        if not isinstance(scheduled_at, str):
            return False
        value = scheduled_at.strip()
        if len(value) != 5 or value[2] != ":":
            return False
        hour_text, minute_text = value.split(":", 1)
        if not hour_text.isdigit() or not minute_text.isdigit():
            return False

        try:
            tz = ZoneInfo(app_timezone)
            now = datetime.now(tz)
            scheduled = now.replace(
                hour=int(hour_text),
                minute=int(minute_text),
                second=0,
                microsecond=0,
            )
        except Exception:
            return False

        elapsed_seconds = (now - scheduled).total_seconds()
        return 0 <= elapsed_seconds <= 8 * 60 * 60

    def _append_parsed_matches(
        self,
        matches: list[dict[str, Any]],
        seen: set[str],
        sections: list[Any],
        status: str,
    ) -> None:
        for section in sections:
            for el in self._match_elements(section):
                m = self._parse_el(el, status)
                if not m:
                    continue
                external_id = str(m.get("external_id") or "")
                if external_id in seen:
                    continue
                seen.add(external_id)
                matches.append(m)

    def _parse_html(self, soup: BeautifulSoup) -> list[dict[str, Any]]:
        matches: list[dict[str, Any]] = []
        seen: set[str] = set()

        # === Live matches ===
        self._append_parsed_matches(matches, seen, soup.select(".liveMatches, .liveMatch, .live-match-container, [live=true]"), "live")

        # === Upcoming ===
        self._append_parsed_matches(
            matches,
            seen,
            soup.select(".upcomingMatchesSection, .upcomingMatch, .match-day, .upcoming-match"),
            "upcoming",
        )

        # === Results ===
        self._append_parsed_matches(
            matches,
            seen,
            soup.select(".results, .result-con, .results-holder"),
            "completed",
        )

        # Fallback: any match-id on page
        if not matches:
            for el in self._match_elements(soup):
                m = self._parse_el(el, "upcoming")
                if m:
                    matches.append(m)

        print(f"HLTV Engine: parsed {len(matches)} matches from HTML", flush=True)
        return matches

    def _parse_results_html(self, soup: BeautifulSoup) -> list[dict[str, Any]]:
        matches: list[dict[str, Any]] = []
        seen: set[str] = set()
        for el in soup.select(".result-con"):
            m = self._parse_el(el, "completed")
            if not m:
                continue
            external_id = str(m.get("external_id") or "")
            if external_id in seen:
                continue
            seen.add(external_id)
            matches.append(m)
        print(f"HLTV Engine: parsed {len(matches)} completed matches from results HTML", flush=True)
        return matches

    @staticmethod
    def _parse_el(el, status: str) -> dict[str, Any] | None:
        link_el = el if el.name == "a" else el.select_one("a[href^='/matches/']")
        href = link_el.get("href") if link_el else None
        match_id = el.get("data-match-id", "").strip()
        if not match_id and href:
            parts = href.strip("/").split("/")
            if len(parts) >= 2 and parts[0] == "matches":
                match_id = parts[1]
        if not match_id:
            return None

        # Team names
        team1_el = el.select_one(".team1, .matchTeam1, .team-left, [class*=team1], [class*=Team1]")
        team2_el = el.select_one(".team2, .matchTeam2, .team-right, [class*=team2], [class*=Team2]")
        team1 = team1_el.get_text(strip=True) if team1_el else ""
        team2 = team2_el.get_text(strip=True) if team2_el else ""

        if not team1 or not team2:
            teams_el = el.select(".match-teamname")
            if len(teams_el) < 2:
                teams_el = el.select(".match-team")
            if len(teams_el) < 2:
                teams_el = el.select(".team")
            if len(teams_el) >= 2:
                team1 = teams_el[0].get_text(strip=True)
                team2 = teams_el[1].get_text(strip=True)

        if not team1 or not team2:
            return None

        # Scores
        scores = []
        for s in el.select(".score, [class*=score]"):
            t = s.get_text(strip=True)
            if t.isdigit():
                scores.append(int(t))
        score1 = scores[0] if len(scores) > 0 else None
        score2 = scores[1] if len(scores) > 1 else None

        # Time
        time_el = el.select_one(".time, [class*=time], [data-zonedgrouping-entry-unix]")
        scheduled_at = None
        if time_el:
            scheduled_at = time_el.get("data-zonedgrouping-entry-unix") or time_el.get_text(strip=True)

        # Tournament
        event_el = el.select_one(".event, .tournament, [class*=event], [class*=tournament]")
        tournament = event_el.get_text(strip=True) if event_el else ""

        # Match detail page URL
        if href and href.startswith("/matches/"):
            detail_url = f"https://www.hltv.org{href}"
        else:
            detail_url = f"https://www.hltv.org/matches/{match_id}/match"

        return {
            "external_id": f"hltv-{match_id}",
            "name": f"{team1} vs {team2}",
            "status": status,
            "scheduled_at": scheduled_at,
            "video_game": "cs2",
            "teams": [
                {"name": team1, "score": score1},
                {"name": team2, "score": score2},
            ],
            "tournament_name": tournament,
            "stars": len(el.select(".star, [class*=star]")) or None,
            "detail_url": detail_url,
        }


    # ------------------------------------------------------------------
    # DB & Smart Reconciliation
    # ------------------------------------------------------------------

    def _find_primary_match_id(
        self,
        conn: Connection,
        team1: str,
        team2: str,
        exclude_match_id: str | None = None,
    ) -> str | None:
        """Find an existing PandaScore match that has these two teams (fuzzy matching)."""
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT m.id,
                           m.name,
                           m.status,
                           COALESCE(
                               jsonb_agg(
                                   jsonb_build_object(
                                       'name', team.name,
                                       'short_name', team.short_name
                                   )
                                   ORDER BY mp.seed NULLS LAST, mp.side
                               ) FILTER (WHERE team.id IS NOT NULL),
                               '[]'::jsonb
                           ) AS teams
                    FROM matches m
                    LEFT JOIN match_participants mp ON mp.match_id = m.id
                    LEFT JOIN teams team ON team.id = mp.team_id
                    WHERE m.game_id = (SELECT id FROM games WHERE code = 'cs2' LIMIT 1)
                      AND (%s::uuid IS NULL OR m.id <> %s::uuid)
                      AND m.status IN ('live', 'completed', 'finished', 'scheduled', 'upcoming', 'pre_match')
                      AND (
                          m.scheduled_at IS NULL
                          OR m.scheduled_at >= now() - interval '14 days'
                          OR m.begin_at >= now() - interval '14 days'
                          OR m.created_at >= now() - interval '14 days'
                      )
                    GROUP BY m.id
                    ORDER BY
                        CASE
                            WHEN m.status = 'live' THEN 0
                            WHEN m.status IN ('completed', 'finished') THEN 1
                            ELSE 2
                        END,
                        m.scheduled_at DESC NULLS LAST,
                        m.created_at DESC
                    """,
                    (exclude_match_id, exclude_match_id),
                )
                candidate_matches = cur.fetchall()
                
                # Normalize team names for fuzzy matching
                t1_clean = team1.lower().strip()
                t2_clean = team2.lower().strip()
                
                t1_norm = self._clean_name(t1_clean)
                t2_norm = self._clean_name(t2_clean)
                
                for match_row in candidate_matches:
                    match_id, match_name = match_row["id"], match_row["name"]
                    teams = match_row.get("teams") or []
                    team_candidates = [
                        str(item.get("name") or item.get("short_name") or "")
                        for item in teams
                        if isinstance(item, dict)
                    ]

                    if len(team_candidates) >= 2:
                        db_t1_norm = self._clean_name(team_candidates[0])
                        db_t2_norm = self._clean_name(team_candidates[1])
                        if self._team_pair_matches(t1_norm, t2_norm, db_t1_norm, db_t2_norm):
                            return match_id

                    # Fallback for records that do not have participant rows yet.
                    m_name_clean = match_name.lower()
                    if " vs " in m_name_clean:
                        parts = m_name_clean.split(" vs ")
                        db_t1_norm = self._clean_name(parts[0])
                        db_t2_norm = self._clean_name(parts[1])
                        if self._team_pair_matches(t1_norm, t2_norm, db_t1_norm, db_t2_norm):
                            return match_id
        except Exception as e:
            print(f"HLTV Engine: match lookup error: {e}", flush=True)
        return None

    @staticmethod
    def _names_match(left: str, right: str) -> bool:
        return bool(left and right and (left in right or right in left))

    def _team_pair_matches(self, t1_norm: str, t2_norm: str, db_t1_norm: str, db_t2_norm: str) -> bool:
        direct = self._names_match(t1_norm, db_t1_norm) and self._names_match(t2_norm, db_t2_norm)
        reverse = self._names_match(t1_norm, db_t2_norm) and self._names_match(t2_norm, db_t1_norm)
        return direct or reverse

    @staticmethod
    def _clean_name(name: str) -> str:
        cleaned = name.lower().strip()
        for word in ["esports", "gaming", "team", "clan", "club"]:
            cleaned = cleaned.replace(word, "")
        return "".join(c for c in cleaned if c.isalnum())

    def _upsert_live_state(self, conn: Connection, match_id: str, status: str, state: dict) -> None:
        """Upsert current scores to live_match_states."""
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO live_match_states (
                        match_id, status, state, source_provider_id, provider_freshness_at, updated_at
                    )
                    VALUES (%s, %s, %s, %s, now(), now())
                    ON CONFLICT (match_id) DO UPDATE SET
                        status = EXCLUDED.status,
                        state = EXCLUDED.state,
                        source_provider_id = EXCLUDED.source_provider_id,
                        provider_freshness_at = now(),
                        updated_at = now()
                    """,
                    (match_id, status, Jsonb(state), UUID(self.provider_id))
                )
        except Exception as e:
            print(f"HLTV Engine: live state upsert error: {e}", flush=True)

    def _current_match_game_id(self, conn: Connection, match_id: str) -> str | None:
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id
                    FROM match_games
                    WHERE match_id = %s
                    ORDER BY
                        CASE
                            WHEN status IN ('live', 'running', 'in_progress') THEN 0
                            WHEN status IN ('scheduled', 'upcoming') THEN 1
                            WHEN status IN ('completed', 'finished') THEN 2
                            ELSE 3
                        END,
                        CASE
                            WHEN status IN ('scheduled', 'upcoming') THEN game_number
                            ELSE -game_number
                        END
                    LIMIT 1
                    """,
                    (match_id,),
                )
                row = cur.fetchone()
                return str(row["id"]) if row else None
        except Exception as exc:
            print(f"HLTV Engine: current map lookup error: {exc}", flush=True)
            return None

    def _participant_team_ids_in_hltv_order(self, conn: Connection, match_id: str, hltv_team_names: list[str]) -> list[str]:
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT mp.team_id, team.name
                    FROM match_participants mp
                    JOIN teams team ON team.id = mp.team_id
                    WHERE mp.match_id = %s
                      AND mp.team_id IS NOT NULL
                    ORDER BY mp.seed NULLS LAST, mp.side
                    LIMIT 2
                    """,
                    (match_id,),
                )
                rows = cur.fetchall()
        except Exception as exc:
            print(f"HLTV Engine: participant lookup error: {exc}", flush=True)
            return []

        if len(rows) < 2:
            return []

        matched: list[str] = []
        used: set[str] = set()
        for hltv_name in hltv_team_names[:2]:
            hltv_norm = self._clean_name(hltv_name)
            best_row = None
            for row in rows:
                team_id = str(row["team_id"])
                if team_id in used:
                    continue
                db_norm = self._clean_name(str(row["name"]))
                if hltv_norm in db_norm or db_norm in hltv_norm:
                    best_row = row
                    break
            if best_row is None:
                continue
            team_id = str(best_row["team_id"])
            used.add(team_id)
            matched.append(team_id)

        if len(matched) == 2:
            return matched

        return [str(row["team_id"]) for row in rows[:2]]

    @staticmethod
    def _scores_look_like_cs2_rounds(scores: list[int | None]) -> bool:
        values = [score for score in scores if isinstance(score, int)]
        if len(values) < 2:
            return False
        # HLTV match-list values can be series map wins. Treat them as round
        # scores only after they exceed plausible BO-series values.
        return max(values) >= 4 or sum(values) >= 8

    def _upsert_cs2_map_round_scores(
        self,
        conn: Connection,
        match_id: str,
        hltv_team_names: list[str],
        scores: list[int | None],
        source_payload: dict[str, Any],
    ) -> None:
        """Fallback: updates only total rounds from overall match list scores when details page HTML is unavailable."""
        if not self._scores_look_like_cs2_rounds(scores):
            return

        match_game_id = self._current_match_game_id(conn, match_id)
        if not match_game_id:
            return

        team_ids = self._participant_team_ids_in_hltv_order(conn, match_id, hltv_team_names)
        if len(team_ids) < 2:
            return

        try:
            with conn.cursor() as cur:
                for index, team_id in enumerate(team_ids[:2]):
                    total_rounds = scores[index] if scores[index] is not None else 0
                    cur.execute(
                        """
                        INSERT INTO match_game_scores (
                            match_game_id,
                            team_id,
                            total_rounds,
                            first_half_rounds,
                            second_half_rounds,
                            overtime_rounds,
                            current_side,
                            source_provider_id,
                            provider_freshness_at,
                            metadata
                        )
                        VALUES (%s, %s, %s, NULL, NULL, NULL, NULL, %s, now(), %s)
                        ON CONFLICT (match_game_id, team_id) DO UPDATE SET
                            total_rounds = CASE 
                                WHEN EXISTS (
                                    SELECT 1 FROM match_game_scores mgs
                                    JOIN providers p ON p.id = mgs.source_provider_id
                                    WHERE mgs.match_game_id = EXCLUDED.match_game_id 
                                      AND mgs.team_id = EXCLUDED.team_id
                                      AND p.code IN ('pandascore', 'grid', 'steam_web_api')
                                ) THEN match_game_scores.total_rounds
                                ELSE EXCLUDED.total_rounds
                            END,
                            source_provider_id = CASE 
                                WHEN EXISTS (
                                    SELECT 1 FROM match_game_scores mgs
                                    JOIN providers p ON p.id = mgs.source_provider_id
                                    WHERE mgs.match_game_id = EXCLUDED.match_game_id 
                                      AND mgs.team_id = EXCLUDED.team_id
                                      AND p.code IN ('pandascore', 'grid', 'steam_web_api')
                                ) THEN match_game_scores.source_provider_id
                                ELSE EXCLUDED.source_provider_id
                            END,
                            provider_freshness_at = now(),
                            metadata = match_game_scores.metadata || EXCLUDED.metadata,
                            updated_at = now()
                        """,
                        (
                            match_game_id,
                            team_id,
                            total_rounds,
                            UUID(self.provider_id),
                            Jsonb(
                                {
                                    "source": "hltv",
                                    "confidence": "round_score_like",
                                    "external_match_id": source_payload.get("external_id"),
                                    "team_index": index,
                                }
                            ),
                        ),
                    )
        except Exception as exc:
            print(f"HLTV Engine: fallback map round score upsert error: {exc}", flush=True)

    def _sync_detail_page_scores(
        self,
        conn: Connection,
        match_uuid: str,
        hltv_team_names: list[str],
        detail_html: str,
        source_payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        """Parses individual mapholder statistics from detail page and saves live/completed round scores."""
        soup = BeautifulSoup(detail_html, "lxml")
        mapholders = soup.select(".mapholder")
        if not mapholders:
            print(f"HLTV Engine: HLTV detail fetcher / optional enrichment found no maps for match {match_uuid}", flush=True)
            return []

        team_ids = self._participant_team_ids_in_hltv_order(conn, match_uuid, hltv_team_names)
        if len(team_ids) < 2:
            print(f"HLTV Engine: HLTV detail fetcher / optional enrichment could not resolve participants for match {match_uuid}", flush=True)
            return []

        print(f"HLTV Engine: HLTV detail fetcher / optional enrichment parsing {len(mapholders)} maps for match {match_uuid}", flush=True)
        parsed_maps: list[dict[str, Any]] = []

        for game_number, mapholder in enumerate(mapholders, start=1):
            try:
                mapname_el = mapholder.select_one(".mapname")
                if not mapname_el:
                    continue
                map_name = mapname_el.get_text(strip=True)
                if not map_name or map_name.upper() == "TBA":
                    continue

                # Parse overall map scores
                score1_el = mapholder.select_one(".results-left .results-team-score")
                score2_el = mapholder.select_one(".results-right .results-team-score")
                if not score1_el or not score2_el:
                    scores = mapholder.select(".results-team-score")
                    if len(scores) >= 2:
                        score1_el, score2_el = scores[0], scores[1]

                if not score1_el or not score2_el:
                    print(f"HLTV Engine: skipped map {map_name} because no round score available in DOM", flush=True)
                    continue

                s1_text = score1_el.get_text(strip=True)
                s2_text = score2_el.get_text(strip=True)
                if not s1_text.isdigit() or not s2_text.isdigit():
                    print(f"HLTV Engine: skipped map {map_name} because score is not numeric ('{s1_text}':'{s2_text}')", flush=True)
                    continue

                s1 = int(s1_text)
                s2 = int(s2_text)

                # Skip 1-0 or 1-1 fake series scores
                if s1 <= 1 and s2 <= 1 and (s1 + s2 <= 2):
                    # In CS2, a map score of 1-0 or 1-1 might represent series score mistakenly shown, 
                    # but if it has no halves, we skip it.
                    half_score_el = mapholder.select_one(".results-center-half-score")
                    if not half_score_el:
                        print(f"HLTV Engine: skipped map {map_name} because scores {s1}-{s2} look like fake series scores", flush=True)
                        continue

                # Determine map status: look for playing class indicators in mapholder, otherwise fallback to score math
                classes = mapholder.get("class", [])
                is_live_class = any(c in classes for c in ["playing", "live"]) or any("playing" in c or "live" in c for c in classes)
                is_live_el = mapholder.select_one(".playing, .live, [class*=playing], [class*=live]")
                is_live = (is_live_class or is_live_el is not None) and not self._is_map_completed(s1, s2)

                if self._is_map_completed(s1, s2):
                    map_status = "completed"
                elif is_live:
                    map_status = "live"
                elif s1 > 0 or s2 > 0:
                    map_status = "live"
                else:
                    map_status = "scheduled"

                # If match overall is completed, then this map must be completed too
                if source_payload.get("status") == "completed" and map_status == "live":
                    map_status = "completed"

                winner_team_id = None
                if map_status == "completed":
                    if s1 > s2:
                        winner_team_id = team_ids[0]
                    elif s2 > s1:
                        winner_team_id = team_ids[1]

                # 1. Upsert match_game
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO match_games (
                            match_id,
                            game_number,
                            map_name,
                            status,
                            winner_team_id,
                            metadata,
                            updated_at
                        )
                        VALUES (%s, %s, %s, %s, %s, %s, now())
                        ON CONFLICT (match_id, game_number) DO UPDATE SET
                            map_name = COALESCE(EXCLUDED.map_name, match_games.map_name),
                            status = EXCLUDED.status,
                            winner_team_id = COALESCE(EXCLUDED.winner_team_id, match_games.winner_team_id),
                            metadata = match_games.metadata || EXCLUDED.metadata,
                            updated_at = now()
                        RETURNING id
                        """,
                        (
                            match_uuid,
                            game_number,
                            map_name,
                            map_status,
                            winner_team_id,
                            Jsonb({"source": "hltv"}),
                        )
                    )
                    row = cur.fetchone()
                    match_game_uuid = row["id"] if row else None

                if not match_game_uuid:
                    continue

                # 2. Parse halves breakdown
                half_score_el = mapholder.select_one(".results-center-half-score")
                valid_halves = []
                if half_score_el:
                    spans = [span for span in half_score_el.select("span") if any(c in span.get("class", []) for c in ["ct", "t"])]
                    for i in range(0, len(spans) - 1, 2):
                        span1 = spans[i]
                        span2 = spans[i+1]
                        t1_t = span1.get_text(strip=True)
                        t2_t = span2.get_text(strip=True)
                        if t1_t.isdigit() and t2_t.isdigit():
                            sc1 = int(t1_t)
                            sc2 = int(t2_t)
                            sd1 = "CT" if "ct" in span1.get("class", []) else "T"
                            sd2 = "CT" if "ct" in span2.get("class", []) else "T"
                            valid_halves.append((sc1, sc2, sd1, sd2))

                # Team 1 splits
                first_half_1 = valid_halves[0][0] if len(valid_halves) >= 1 else None
                second_half_1 = valid_halves[1][0] if len(valid_halves) >= 2 else None
                ot_1 = sum(h[0] for h in valid_halves[2:]) if len(valid_halves) >= 3 else None
                side_1 = valid_halves[-1][2] if len(valid_halves) >= 1 else None

                # Team 2 splits
                first_half_2 = valid_halves[0][1] if len(valid_halves) >= 1 else None
                second_half_2 = valid_halves[1][1] if len(valid_halves) >= 2 else None
                ot_2 = sum(h[1] for h in valid_halves[2:]) if len(valid_halves) >= 3 else None
                side_2 = valid_halves[-1][3] if len(valid_halves) >= 1 else None

                # 3. Upsert round scores with strict authority rules for both teams
                with conn.cursor() as cur:
                    for index, (t_id, tot, fh, sh, ot, sd) in enumerate([
                        (team_ids[0], s1, first_half_1, second_half_1, ot_1, side_1),
                        (team_ids[1], s2, first_half_2, second_half_2, ot_2, side_2),
                    ]):
                        cur.execute(
                            """
                            INSERT INTO match_game_scores (
                                match_game_id,
                                team_id,
                                total_rounds,
                                first_half_rounds,
                                second_half_rounds,
                                overtime_rounds,
                                current_side,
                                source_provider_id,
                                provider_freshness_at,
                                metadata,
                                created_at,
                                updated_at
                            )
                            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, now(), %s, now(), now())
                            ON CONFLICT (match_game_id, team_id) DO UPDATE SET
                                total_rounds = CASE 
                                    WHEN EXISTS (
                                        SELECT 1 FROM match_game_scores mgs
                                        JOIN providers p ON p.id = mgs.source_provider_id
                                        WHERE mgs.match_game_id = EXCLUDED.match_game_id 
                                          AND mgs.team_id = EXCLUDED.team_id
                                          AND p.code IN ('pandascore', 'grid', 'steam_web_api')
                                    ) THEN match_game_scores.total_rounds
                                    ELSE EXCLUDED.total_rounds
                                END,
                                first_half_rounds = CASE 
                                    WHEN EXISTS (
                                        SELECT 1 FROM match_game_scores mgs
                                        JOIN providers p ON p.id = mgs.source_provider_id
                                        WHERE mgs.match_game_id = EXCLUDED.match_game_id 
                                          AND mgs.team_id = EXCLUDED.team_id
                                          AND p.code IN ('pandascore', 'grid', 'steam_web_api')
                                    ) THEN match_game_scores.first_half_rounds
                                    ELSE EXCLUDED.first_half_rounds
                                END,
                                second_half_rounds = CASE 
                                    WHEN EXISTS (
                                        SELECT 1 FROM match_game_scores mgs
                                        JOIN providers p ON p.id = mgs.source_provider_id
                                        WHERE mgs.match_game_id = EXCLUDED.match_game_id 
                                          AND mgs.team_id = EXCLUDED.team_id
                                          AND p.code IN ('pandascore', 'grid', 'steam_web_api')
                                    ) THEN match_game_scores.second_half_rounds
                                    ELSE EXCLUDED.second_half_rounds
                                END,
                                overtime_rounds = CASE 
                                    WHEN EXISTS (
                                        SELECT 1 FROM match_game_scores mgs
                                        JOIN providers p ON p.id = mgs.source_provider_id
                                        WHERE mgs.match_game_id = EXCLUDED.match_game_id 
                                          AND mgs.team_id = EXCLUDED.team_id
                                          AND p.code IN ('pandascore', 'grid', 'steam_web_api')
                                    ) THEN match_game_scores.overtime_rounds
                                    ELSE EXCLUDED.overtime_rounds
                                END,
                                current_side = CASE 
                                    WHEN EXISTS (
                                        SELECT 1 FROM match_game_scores mgs
                                        JOIN providers p ON p.id = mgs.source_provider_id
                                        WHERE mgs.match_game_id = EXCLUDED.match_game_id 
                                          AND mgs.team_id = EXCLUDED.team_id
                                          AND p.code IN ('pandascore', 'grid', 'steam_web_api')
                                    ) THEN match_game_scores.current_side
                                    ELSE EXCLUDED.current_side
                                END,
                                source_provider_id = CASE 
                                    WHEN EXISTS (
                                        SELECT 1 FROM match_game_scores mgs
                                        JOIN providers p ON p.id = mgs.source_provider_id
                                        WHERE mgs.match_game_id = EXCLUDED.match_game_id 
                                          AND mgs.team_id = EXCLUDED.team_id
                                          AND p.code IN ('pandascore', 'grid', 'steam_web_api')
                                    ) THEN match_game_scores.source_provider_id
                                    ELSE EXCLUDED.source_provider_id
                                END,
                                provider_freshness_at = now(),
                                metadata = match_game_scores.metadata || EXCLUDED.metadata,
                                updated_at = now()
                            """,
                            (
                                match_game_uuid,
                                t_id,
                                tot,
                                fh,
                                sh,
                                ot,
                                sd,
                                UUID(self.provider_id),
                                Jsonb({
                                    "source": "hltv",
                                    "confidence": "detail_enrichment",
                                    "hltv_parsed_map": {
                                        "map_name": map_name,
                                        "score_team1": s1,
                                        "score_team2": s2,
                                        "halves": valid_halves,
                                        "side_team1": side_1,
                                        "side_team2": side_2,
                                    }
                                })
                            )
                        )

                print(f"HLTV Engine: HLTV detail fetcher / optional enrichment round scores upserted for map {map_name} (Game #{game_number}): {s1} ({side_1}) vs {s2} ({side_2})", flush=True)
                parsed_maps.append(
                    {
                        "game_number": game_number,
                        "map_name": map_name,
                        "status": map_status,
                        "team_scores": [
                            {
                                "team_id": str(team_ids[0]),
                                "team_name": hltv_team_names[0] if len(hltv_team_names) > 0 else None,
                                "total_rounds": s1,
                                "first_half_rounds": first_half_1,
                                "second_half_rounds": second_half_1,
                                "overtime_rounds": ot_1,
                                "current_side": side_1,
                            },
                            {
                                "team_id": str(team_ids[1]),
                                "team_name": hltv_team_names[1] if len(hltv_team_names) > 1 else None,
                                "total_rounds": s2,
                                "first_half_rounds": first_half_2,
                                "second_half_rounds": second_half_2,
                                "overtime_rounds": ot_2,
                                "current_side": side_2,
                            },
                        ],
                    }
                )

            except Exception as e:
                print(f"HLTV Engine: error syncing detail map for match {match_uuid} game {game_number}: {e}", flush=True)
        return parsed_maps

    def _remember_detail_enrichment_payload(
        self,
        conn: Connection,
        match_uuid: str,
        source_payload: dict[str, Any],
        parsed_maps: list[dict[str, Any]],
    ) -> None:
        if not parsed_maps:
            return
        try:
            from esports360.storage import remember_payload

            remember_payload(
                conn,
                provider_id=UUID(self.provider_id),
                feed_type="hltv_detail_enrichment",
                entity_type="match",
                entity_id=UUID(str(match_uuid)),
                external_id=source_payload.get("external_id"),
                endpoint=source_payload.get("detail_url"),
                payload={
                    "external_match_id": source_payload.get("external_id"),
                    "match_name": source_payload.get("name"),
                    "status": source_payload.get("status"),
                    "detail_url": source_payload.get("detail_url"),
                    "parsed_map_count": len(parsed_maps),
                    "parsed_maps": parsed_maps,
                },
            )
            print(
                "HLTV Engine: HLTV detail fetcher / optional enrichment proof payload stored "
                f"for {source_payload.get('name')} ({len(parsed_maps)} maps)",
                flush=True,
            )
        except Exception as exc:
            print(f"HLTV Engine: detail enrichment payload audit error: {exc}", flush=True)

    @staticmethod
    def _is_map_completed(s1: int, s2: int) -> bool:
        """
        Deduce if a CS2 map has ended based on scores.
        MR12 format regulation ends at 13 points (minimum 2 lead, e.g. 13-11).
        Overtime (OT) block MR3 format ends when one team has at least 16, 19, 22... points with a 2 lead.
        """
        if s1 < 13 and s2 < 13:
            return False
        if abs(s1 - s2) < 2:
            return False
        if max(s1, s2) == 13:
            return True
        max_val = max(s1, s2)
        if max_val >= 16 and (max_val - 13) % 3 == 0:
            return True
        return False

    @staticmethod
    def _match_metadata(match: dict[str, Any]) -> Jsonb:
        hltv = {key: value for key, value in match.items() if key != "detail_html"}
        if "detail_html" in match:
            hltv["detail_html_present"] = True
        return Jsonb({"hltv": hltv})


    def _upsert_matches(self, conn: Connection, matches_data: list[dict[str, Any]]) -> int:
        count = 0
        from esports360.storage import find_entity_by_external_id, remember_external_id
        
        # Get CS2 game ID
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM games WHERE code = 'cs2'")
            row = cur.fetchone()
            if not row:
                print("HLTV Engine: CS2 game not found in database!", flush=True)
                return 0
            game_id = row["id"]

        for m in matches_data:
            try:
                ext_id = m.get("external_id", "")
                if not ext_id:
                    continue

                # 1. Normalize/upsert teams
                team_ids = []
                for team_data in m.get("teams", []):
                    team_name = team_data.get("name", "")
                    if not team_name:
                        continue
                        
                    team_ext_id = f"hltv-{team_name.lower().replace(' ', '-')}"
                    
                    # Look up in provider_entity_map
                    team_id = find_entity_by_external_id(
                        conn,
                        provider_id=UUID(self.provider_id),
                        entity_type="team",
                        external_id=team_ext_id
                    )
                    
                    if not team_id:
                        # Slug clean
                        slug = team_name.lower()
                        slug = "".join(c if c.isalnum() or c == " " else " " for c in slug)
                        slug = "-".join(slug.split())[:200]
                        
                        # Upsert team
                        with conn.cursor() as cur:
                            cur.execute(
                                """
                                INSERT INTO teams (primary_game_id, name, slug, metadata, created_at, updated_at)
                                VALUES (%s, %s, %s, %s, now(), now())
                                ON CONFLICT (slug) DO UPDATE SET
                                    name = EXCLUDED.name,
                                    updated_at = now()
                                RETURNING id
                                """,
                                (game_id, team_name, slug, Jsonb({"hltv": {"name": team_name}}))
                            )
                            team_id = cur.fetchone()["id"]
                            
                        # Remember external ID
                        remember_external_id(
                            conn,
                            provider_id=UUID(self.provider_id),
                            entity_type="team",
                            entity_id=team_id,
                            external_id=team_ext_id,
                            external_slug=slug
                        )
                    team_ids.append(team_id)

                # 2. Look up match using provider_entity_map
                match_id = find_entity_by_external_id(
                    conn,
                    provider_id=UUID(self.provider_id),
                    entity_type="match",
                    external_id=ext_id
                )

                # Normalize slug
                match_slug = m.get("name", "").lower()
                match_slug = "".join(c if c.isalnum() or c == " " else " " for c in match_slug)
                match_slug = "-".join(match_slug.split())[:200]
                
                # Check status
                status = m.get("status", "upcoming")
                if status == "live":
                    status = "live"
                elif status == "completed":
                    status = "completed"
                else:
                    status = "scheduled"

                # Parse Unix timestamp scheduled_at
                sched_unix = m.get("scheduled_at")
                sched_dt = None
                if sched_unix and sched_unix.isdigit():
                    from datetime import datetime, timezone
                    sched_dt = datetime.fromtimestamp(int(sched_unix), timezone.utc)

                if not match_id:
                    # Insert new match
                    with conn.cursor() as cur:
                        cur.execute(
                            """
                            INSERT INTO matches (
                                game_id, name, slug, status, scheduled_at, metadata, created_at, updated_at
                            )
                            VALUES (%s, %s, %s, %s, %s, %s, now(), now())
                            ON CONFLICT (slug) DO UPDATE SET
                                status = EXCLUDED.status,
                                metadata = matches.metadata || EXCLUDED.metadata,
                                updated_at = now()
                            RETURNING id
                            """,
                            (
                                game_id,
                                m.get("name", ""),
                                match_slug,
                                status,
                                sched_dt,
                                self._match_metadata(m),
                            )
                        )
                        row = cur.fetchone()
                        if row:
                            match_id = row["id"]
                            remember_external_id(
                                conn,
                                provider_id=UUID(self.provider_id),
                                entity_type="match",
                                entity_id=match_id,
                                external_id=ext_id,
                                external_slug=match_slug
                            )
                else:
                    # Update existing match
                    with conn.cursor() as cur:
                        cur.execute(
                            """
                            UPDATE matches SET
                                status = %s,
                                metadata = metadata || %s,
                                updated_at = now()
                            WHERE id = %s
                            """,
                            (status, self._match_metadata(m), match_id)
                        )

                if match_id:
                    count += 1

                    for index, team_id in enumerate(team_ids[:2]):
                        side = "home" if index == 0 else "away"
                        team_score = m.get("teams", [])[index].get("score") if len(m.get("teams", [])) > index else None
                        with conn.cursor() as cur:
                            cur.execute(
                                """
                                INSERT INTO match_participants (
                                    match_id,
                                    participant_type,
                                    team_id,
                                    side,
                                    seed,
                                    score,
                                    metadata,
                                    created_at,
                                    updated_at
                                )
                                VALUES (%s, 'team', %s, %s, %s, %s, %s, now(), now())
                                ON CONFLICT (match_id, side) DO UPDATE SET
                                    team_id = EXCLUDED.team_id,
                                    seed = EXCLUDED.seed,
                                    score = EXCLUDED.score,
                                    metadata = match_participants.metadata || EXCLUDED.metadata,
                                    updated_at = now()
                                """,
                                (
                                    match_id,
                                    team_id,
                                    side,
                                    index + 1,
                                    team_score if team_score is not None else 0,
                                    Jsonb({"source": "hltv", "team_index": index}),
                                ),
                            )
                    
                    # 3. Smart lookup of PandaScore match so HLTV map scores land on the app-visible match.
                    primary_match_id = match_id
                    t_names = [t.get("name", "") for t in m.get("teams", [])]
                    if len(t_names) == 2:
                        found_primary = self._find_primary_match_id(
                            conn,
                            t_names[0],
                            t_names[1],
                            exclude_match_id=str(match_id),
                        )
                        if found_primary:
                            primary_match_id = found_primary
                            print(f"HLTV Engine: linked HLTV match '{m.get('name')}' to primary match {primary_match_id}", flush=True)

                    detail_html = m.get("detail_html")
                    if detail_html and status in {"live", "completed", "scheduled"}:
                        parsed_maps = self._sync_detail_page_scores(
                            conn,
                            primary_match_id,
                            t_names,
                            detail_html,
                            m,
                        )
                        self._remember_detail_enrichment_payload(conn, primary_match_id, m, parsed_maps)
                        if primary_match_id != match_id:
                            parsed_maps = self._sync_detail_page_scores(
                                conn,
                                match_id,
                                t_names,
                                detail_html,
                                m,
                            )
                            self._remember_detail_enrichment_payload(conn, match_id, m, parsed_maps)

                    # 4. Upsert live state if this is live and we have scores
                    if status == "live":
                        scores = [t.get("score") for t in m.get("teams", [])]
                        # Verify we have valid scores
                        if len(scores) == 2 and (scores[0] is not None or scores[1] is not None):
                            score1 = scores[0] if scores[0] is not None else 0
                            score2 = scores[1] if scores[1] is not None else 0
                            
                            live_state = {
                                "source": "hltv",
                                "external_match_id": ext_id,
                                "team_scores": [score1, score2],
                                "round": None,
                                "map": None,
                                "stars": m.get("stars")
                            }
                            
                            # Upsert live state for both the primary (PandaScore) match and the fallback (HLTV) match
                            self._upsert_live_state(conn, primary_match_id, "live", live_state)
                            if primary_match_id != match_id:
                                self._upsert_live_state(conn, match_id, "live", live_state)

                            if not detail_html:
                                self._upsert_cs2_map_round_scores(
                                    conn,
                                    primary_match_id,
                                    t_names,
                                    [score1, score2],
                                    m,
                                )


                            # 5. Insert match scores snapshot for primary match
                            for i, t_id in enumerate(team_ids[:2]):
                                val = score1 if i == 0 else score2
                                with conn.cursor() as cur:
                                    cur.execute(
                                        """
                                        INSERT INTO match_scores (match_id, score_type, game_number, value, recorded_at, metadata)
                                        VALUES (%s, 'map', 1, %s, now(), %s)
                                        """,
                                        (primary_match_id, val, Jsonb({"source": "hltv", "team_index": i}))
                                    )

            except Exception as exc:
                print(f"HLTV Engine: row error: {exc}", flush=True)
                import traceback
                traceback.print_exc()
        return count
