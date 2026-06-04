"""
Router: /v1/tournaments/*
"""
from fastapi import APIRouter, HTTPException, Query
from esports360.queries import list_tournaments, get_tournament
from .meta import _meta

router = APIRouter(prefix="/v1/tournaments", tags=["Tournaments"])


@router.get("")
def tournaments(
    limit:    int        = Query(default=80, ge=1, le=100),
    status:   str | None = Query(default=None),
    featured: bool       = Query(default=False),
) -> dict:
    return {
        "data": list_tournaments(limit=limit, status=status, featured=featured),
        "meta": _meta("tournaments"),
    }


@router.get("/{tournament_id}")
def tournament_detail(tournament_id: str) -> dict:
    tournament = get_tournament(tournament_id)
    if not tournament:
        raise HTTPException(status_code=404, detail="tournament_not_found")
    return {"data": tournament}
