# ------------------------------------------------------------------
# Esports360 — CS2 Collector Additions
# Append these to the existing Settings class in config.py and .env
# ------------------------------------------------------------------

# ---- config.py additions (Settings class) ----

# CS2 Collector
    cs2_collector_enabled: bool = True
    cs2_steam_api_key: str = ""
    cs2_hltv_poll_seconds: int = 30


# ---- .env additions ----

CS2_COLLECTOR_ENABLED=true
CS2_HLTV_POLL_SECONDS=30
CS2_STEAM_API_KEY=C3292528718F602D05A0C8107121F577
PANDASCORE_SYNC_EXCLUDE_GAMES=cs2


# ---- docker-compose.yml new service (add inside `services:`) ----

  cs2-collector:
    build:
      context: .
      dockerfile: services/cs2-collector/Dockerfile
    container_name: esports360-cs2-collector
    restart: unless-stopped
    env_file:
      - .env
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - esports360


# ---- worker.py modifications ----

# In sync_pandascore_matches(), add early return inside the videogames check:
# At the top of the function, after `provider = ...`:
#
#     settings = get_settings()
#     if feed_type in ("pandascore_today_matches", "pandascore_live_matches", "pandascore_upcoming_matches"):
#         excluded = [g.strip() for g in getattr(settings, "pandascore_sync_exclude_games", "").split(",") if g.strip()]
#         if "cs2" in excluded:
#             print(f"PandaScore {feed_type}: CS2 excluded, skipping", flush=True)
#             return 0
