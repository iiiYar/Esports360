"""
Esports360 CS2 Collector — Steam Web API Engine

Uses official Steam Web API for CS2 match data:
- Tournament news via ISteamNews
- Game server status via ICSGOServers_730
- Live/upcoming match detection

No external scraping needed — all data comes from Valve's official free API.
"""

import asyncio
import signal
import time

from esports360.config import get_settings
from esports360.database import connect
from esports360.storage import get_provider_id

from engines.steam_api_engine import SteamWebAPIEngine
from engines.hltv_engine import HLTvEngine


running = True


def stop(_: int, __: object) -> None:
    global running
    running = False


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)


async def cs2_collector_loop() -> None:
    settings = get_settings()

    # Register/resolve provider + game
    with connect() as conn:
        steam_provider_id = get_provider_id(conn, "steam_web_api")
        hltv_provider_id = get_provider_id(conn, "hltv")
        # Get CS2 game ID
        cur = conn.cursor()
        cur.execute("SELECT id FROM games WHERE code = 'cs2'")
        game_row = cur.fetchone()
        if not game_row:
            print("CS2 Collector: CS2 game not found in DB. Exiting.", flush=True)
            return
        game_id = game_row["id"]
        conn.commit()

    steam_engine = SteamWebAPIEngine(
        provider_id=steam_provider_id,
        api_key=settings.cs2_steam_api_key,
        game_id=game_id,
        poll_interval=settings.cs2_hltv_poll_seconds,
    )

    hltv_engine = HLTvEngine(
        provider_id=hltv_provider_id,
        poll_interval=settings.cs2_hltv_poll_seconds,
    )

    print(f"CS2 Collector: Steam Web API engine starting (key={'***' + settings.cs2_steam_api_key[-4:] if settings.cs2_steam_api_key else 'MISSING'})", flush=True)
    print(f"CS2 Collector: HLTV Scraper starting (provider={hltv_provider_id})", flush=True)

    await asyncio.gather(
        steam_engine.run(),
        hltv_engine.run(),
    )


def main() -> None:
    settings = get_settings()
    if not settings.cs2_collector_enabled:
        print("CS2 Collector: disabled (CS2_COLLECTOR_ENABLED=false)", flush=True)
        return
    if not settings.cs2_steam_api_key or len(settings.cs2_steam_api_key) < 10:
        print("CS2 Collector: CS2_STEAM_API_KEY missing/invalid. Exiting.", flush=True)
        return

    asyncio.run(cs2_collector_loop())
    print("CS2 Collector stopped.", flush=True)


if __name__ == "__main__":
    main()
