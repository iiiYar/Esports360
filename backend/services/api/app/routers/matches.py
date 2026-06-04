"""
Router: /v1/matches/*
"""
from fastapi import APIRouter, HTTPException, Query
from esports360.queries import list_matches, get_match
from .meta import _meta

router = APIRouter(prefix="/v1/matches", tags=["Matches"])


@router.get("/today")
def matches_today(limit: int = Query(default=50, ge=1, le=100)) -> dict:
    return {"data": list_matches("today", limit=limit), "meta": _meta("today")}


@router.get("/live")
def matches_live(limit: int = Query(default=50, ge=1, le=100)) -> dict:
    return {"data": list_matches("live", limit=limit), "meta": _meta("live")}


@router.get("/upcoming")
def matches_upcoming(limit: int = Query(default=50, ge=1, le=100)) -> dict:
    return {"data": list_matches("upcoming", limit=limit), "meta": _meta("upcoming")}


@router.get("/{match_id}")
def match_detail(match_id: str) -> dict:
    match = get_match(match_id)
    if not match:
        raise HTTPException(status_code=404, detail="match_not_found")
    return {"data": match}
