"""
Router: /health  +  /v1/meta/ports
"""
from fastapi import APIRouter
from esports360.database import check_database
from esports360.config import get_settings

router = APIRouter(tags=["Infrastructure"])
settings = get_settings()


@router.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "api", "database": check_database()}


@router.get("/v1/meta/ports")
def ports() -> dict:
    return {
        "api":      {"container": 8000, "host": settings.api_port, "exposure": "lan"},
        "postgres": {"container": 5432, "host": 5432,             "exposure": "localhost"},
        "redis":    {"container": 6379, "host": 6379,             "exposure": "localhost"},
        "schema":   "created",
    }
