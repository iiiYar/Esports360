"""
Router: /v1/discover/*  +  /v1/games/*
"""
from fastapi import APIRouter, HTTPException, Query
from esports360.queries import (
    list_trending_tournaments,
    list_featured_teams,
    discover_search,
    list_games,
    get_game_hub_details,
)
from .meta import _meta

router = APIRouter(tags=["Discover"])


@router.get("/v1/games")
def games(limit: int = Query(default=50, ge=1, le=100)) -> dict:
    return {"data": list_games(limit=limit), "meta": _meta("games")}


@router.get("/v1/games/{code}/hub")
def game_hub(code: str) -> dict:
    hub = get_game_hub_details(code)
    if not hub:
        raise HTTPException(status_code=404, detail="game_not_found")
    return {"data": hub}


@router.get("/v1/discover/trending")
def discover_trending(
    limit_tournaments: int = Query(default=10, ge=1, le=50),
    limit_teams:       int = Query(default=10, ge=1, le=50),
) -> dict:
    return {
        "tournaments": list_trending_tournaments(limit=limit_tournaments),
        "teams":       list_featured_teams(limit=limit_teams),
    }


@router.get("/v1/discover/search")
def search(q: str = Query(default="", min_length=1)) -> dict:
    return {"data": discover_search(q)}
