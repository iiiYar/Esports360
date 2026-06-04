"""
Router: /v1/teams/*
"""
from fastapi import APIRouter, HTTPException, Query
from esports360.queries import list_teams, count_teams, list_featured_teams, get_team
from .meta import _meta

router = APIRouter(prefix="/v1/teams", tags=["Teams"])


@router.get("/featured")
def featured_teams(limit: int = Query(default=20, ge=1, le=100)) -> dict:
    return {"data": list_featured_teams(limit=limit), "meta": _meta("featured_teams")}


@router.get("")
def teams(
    limit:  int = Query(default=50, ge=1, le=1000),
    offset: int = Query(default=0,  ge=0),
) -> dict:
    rows = list_teams(limit=limit, offset=offset)
    meta = _meta("teams")
    meta["total"]    = count_teams()
    meta["returned"] = len(rows)
    meta["offset"]   = offset
    return {"data": rows, "meta": meta}


@router.get("/{team_id}")
def team_detail(team_id: str) -> dict:
    team = get_team(team_id)
    if not team:
        raise HTTPException(status_code=404, detail="team_not_found")
    return {"data": team}
