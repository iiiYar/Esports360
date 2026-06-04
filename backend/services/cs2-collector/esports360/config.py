from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    api_port: int = 8010
    database_url: str = ""
    redis_url: str = ""

    app_timezone: str = "Asia/Riyadh"

    pandascore_token: str = ""
    pandascore_base_url: str = "https://api.pandascore.co"
    pandascore_sync_enabled: bool = False
    pandascore_sync_on_start: bool = False
    pandascore_today_interval_seconds: int = 300
    pandascore_live_interval_seconds: int = 60
    pandascore_upcoming_interval_seconds: int = 900
    pandascore_upcoming_days: int = 7
    pandascore_roster_interval_hours: int = 12
    pandascore_roster_team_limit: int = 10
    pandascore_priority_team_ids: str = ""

    media_storage_dir: str = "/data/media"
    media_public_base_url: str = "/media"
    object_storage_driver: str = "local"
    s3_endpoint: str = "http://minio:9000"
    s3_bucket: str = "esports360-media"
    s3_access_key: str = ""
    s3_secret_key: str = ""
    s3_secure: bool = False
    image_backfill_on_start: bool = False
    image_backfill_force: bool = False
    image_backfill_interval_hours: int = 24
    image_backfill_limit: int = 500

    cs2_collector_enabled: bool = True
    cs2_steam_api_key: str = ""
    cs2_hltv_poll_seconds: int = 30
    pandascore_sync_exclude_games: str = ""
    cs2_hltv_detail_enabled: bool = True
    cs2_hltv_completed_detail_limit: int = 3



@lru_cache
def get_settings() -> Settings:
    return Settings()
