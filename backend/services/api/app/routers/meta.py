"""
Internal helper: _meta() used by all data routers.
"""
from datetime import datetime
from zoneinfo import ZoneInfo
from fastapi import APIRouter
from esports360.config import get_settings

router   = APIRouter()
settings = get_settings()


def _meta(filter_name: str) -> dict:
    now = datetime.now(ZoneInfo(settings.app_timezone))
    return {
        "filter":      filter_name,
        "timezone":    settings.app_timezone,
        "generatedAt": now.isoformat(),
    }
