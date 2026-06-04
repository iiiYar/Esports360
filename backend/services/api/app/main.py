from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

import bcrypt
import jwt
from fastapi import FastAPI, HTTPException, Query, Response, Header, Depends, status
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from esports360.config import get_settings
from esports360.database import check_database
from esports360.object_storage import get_object_bytes, using_minio
from esports360.queries import (
    count_teams,
    get_match,
    get_team,
    get_tournament,
    list_teams,
    list_tournaments,
    list_featured_teams,
    list_games,
    list_matches,
    create_user_account,
    get_user_account_by_email,
    get_user_account_by_id,
    delete_user_account,
    get_user_preferences,
    update_user_preferences,
    get_user_follows,
    follow_entity,
    unfollow_entity,
    list_trending_tournaments,
    discover_search,
    get_game_hub_details,
)



settings = get_settings()

app = FastAPI(
    title="Esports360 API",
    version="0.1.0",
    description="Provider-neutral backend for Esports360.",
)

if using_minio():

    @app.get("/media/{storage_key:path}")
    def media_object(storage_key: str) -> Response:
        try:
            data, content_type = get_object_bytes(storage_key)
        except FileNotFoundError as error:
            raise HTTPException(status_code=404, detail="media_not_found") from error
        return Response(
            content=data,
            media_type=content_type,
            headers={"Cache-Control": "public, max-age=31536000, immutable"},
        )

else:
    Path(settings.media_storage_dir).mkdir(parents=True, exist_ok=True)
    app.mount("/media", StaticFiles(directory=settings.media_storage_dir), name="media")


@app.get("/health")
def health() -> dict[str, object]:
    database = check_database()
    return {"status": "ok", "service": "api", "database": database}


@app.get("/v1/meta/ports")
def ports() -> dict[str, object]:
    return {
        "api": {"container": 8000, "host": settings.api_port, "exposure": "lan"},
        "postgres": {"container": 5432, "host": 5432, "exposure": "localhost"},
        "redis": {"container": 6379, "host": 6379, "exposure": "localhost"},
        "database_schema": "created",
    }


def _meta(filter_name: str) -> dict[str, str]:
    now = datetime.now(ZoneInfo(settings.app_timezone))
    return {
        "filter": filter_name,
        "timezone": settings.app_timezone,
        "generatedAt": now.isoformat(),
    }


@app.get("/v1/matches/today")
def matches_today(limit: int = Query(default=50, ge=1, le=100)) -> dict[str, object]:
    return {"data": list_matches("today", limit=limit), "meta": _meta("today")}


@app.get("/v1/matches/live")
def matches_live(limit: int = Query(default=50, ge=1, le=100)) -> dict[str, object]:
    return {"data": list_matches("live", limit=limit), "meta": _meta("live")}


@app.get("/v1/matches/upcoming")
def matches_upcoming(limit: int = Query(default=50, ge=1, le=100)) -> dict[str, object]:
    return {"data": list_matches("upcoming", limit=limit), "meta": _meta("upcoming")}


@app.get("/v1/games")
def games(limit: int = Query(default=50, ge=1, le=100)) -> dict[str, object]:
    return {"data": list_games(limit=limit), "meta": _meta("games")}


@app.get("/v1/teams/featured")
def featured_teams(limit: int = Query(default=20, ge=1, le=100)) -> dict[str, object]:
    return {"data": list_featured_teams(limit=limit), "meta": _meta("featured_teams")}


@app.get("/v1/teams")
def teams(
    limit: int = Query(default=50, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
) -> dict[str, object]:
    rows = list_teams(limit=limit, offset=offset)
    meta = _meta("teams")
    meta["total"] = count_teams()
    meta["returned"] = len(rows)
    meta["offset"] = offset
    return {"data": rows, "meta": meta}


@app.get("/v1/matches/{match_id}")
def match_detail(match_id: str) -> dict[str, object]:
    match = get_match(match_id)
    if not match:
        raise HTTPException(status_code=404, detail="match_not_found")
    return {"data": match}


@app.get("/v1/teams/{team_id}")
def team_detail(team_id: str) -> dict[str, object]:
    team = get_team(team_id)
    if not team:
        raise HTTPException(status_code=404, detail="team_not_found")
    return {"data": team}


@app.get("/v1/tournaments")
def tournaments(
    limit: int = Query(default=80, ge=1, le=100),
    status: str | None = Query(default=None),
    featured: bool = Query(default=False),
) -> dict[str, object]:
    return {
        "data": list_tournaments(limit=limit, status=status, featured=featured),
        "meta": _meta("tournaments"),
    }


@app.get("/v1/tournaments/{tournament_id}")
def tournament_detail(tournament_id: str) -> dict[str, object]:
    tournament = get_tournament(tournament_id)
    if not tournament:
        raise HTTPException(status_code=404, detail="tournament_not_found")
    return {"data": tournament}


# --- DISCOVER / EXPLORE PAGE ENDPOINTS ---

@app.get("/v1/discover/trending")
def discover_trending(limit_tournaments: int = 10, limit_teams: int = 10) -> dict[str, object]:
    """Exposes trending tournaments and featured teams for the Discover page carousel and lists."""
    return {
        "tournaments": list_trending_tournaments(limit=limit_tournaments),
        "teams": list_featured_teams(limit=limit_teams)
    }


@app.get("/v1/discover/search")
def search(q: str = Query(default="", min_length=1)) -> dict[str, object]:
    """Provides a global search endpoint across teams, tournaments, and players."""
    return {"data": discover_search(q)}


@app.get("/v1/games/{code}/hub")
def game_hub(code: str) -> dict[str, object]:
    """Returns dedicated Game Hub information for the specified game code."""
    hub = get_game_hub_details(code)
    if not hub:
        raise HTTPException(status_code=404, detail="game_not_found")
    return {"data": hub}


# --- USER AUTHENTICATION & PREFERENCES SYNC ENDPOINTS ---


JWT_SECRET_KEY = settings.jwt_secret_key
if not JWT_SECRET_KEY:
    raise RuntimeError("JWT_SECRET_KEY must be configured in the backend environment")
JWT_ALGORITHM = "HS256"


class AuthRequest(BaseModel):
    email: str
    password: str


class PreferencesUpdateRequest(BaseModel):
    language: str | None = None
    calendarPreference: str | None = None
    saudiFanMode: bool | None = None
    notificationsEnabled: bool | None = None
    notifMatchStart: bool | None = None
    notifScoreChange: bool | None = None
    notifMatchEnd: bool | None = None
    notifRosterChange: bool | None = None
    notifStreamLive: bool | None = None
    notifFantasyRemind: bool | None = None


class FollowRequest(BaseModel):
    entityType: str
    entityId: str
    notificationLevel: str = "normal"


def get_current_user_id(authorization: str = Header(None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="missing_or_invalid_token",
        )
    token = authorization.split(" ")[1]
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="invalid_token_payload",
            )
        return user_id
    except jwt.ExpiredSignatureError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="token_expired",
        ) from e
    except jwt.PyJWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid_token",
        ) from e


@app.post("/v1/auth/signup")
def signup(req: AuthRequest):
    if not req.email or "@" not in req.email or len(req.password) < 6:
        raise HTTPException(
            status_code=400,
            detail="invalid_email_or_password_length",
        )
    
    salt = bcrypt.gensalt()
    hashed_pwd = bcrypt.hashpw(req.password.encode("utf-8"), salt).decode("utf-8")
    
    user = create_user_account(req.email, hashed_pwd)
    if not user:
        raise HTTPException(
            status_code=400,
            detail="email_already_registered",
        )
    
    token = jwt.encode(
        {"sub": user["id"], "exp": datetime.utcnow() + timedelta(days=30)},
        JWT_SECRET_KEY,
        algorithm=JWT_ALGORITHM,
    )
    return {"token": token, "user": user}


@app.post("/v1/auth/login")
def login(req: AuthRequest):
    user = get_user_account_by_email(req.email)
    if not user or not user.get("hashed_password"):
        raise HTTPException(
            status_code=400,
            detail="invalid_credentials",
        )
    
    hashed_password_in_db = user["hashed_password"]
    is_valid = bcrypt.checkpw(
        req.password.encode("utf-8"),
        hashed_password_in_db.encode("utf-8"),
    )
    if not is_valid:
        raise HTTPException(
            status_code=400,
            detail="invalid_credentials",
        )
    
    del user["hashed_password"]
    
    token = jwt.encode(
        {"sub": user["id"], "exp": datetime.utcnow() + timedelta(days=30)},
        JWT_SECRET_KEY,
        algorithm=JWT_ALGORITHM,
    )
    return {"token": token, "user": user}


@app.get("/v1/user/profile")
def user_profile(user_id: str = Depends(get_current_user_id)):
    user = get_user_account_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="user_not_found")
    return {"user": user}


@app.get("/v1/user/preferences")
def user_preferences_get(user_id: str = Depends(get_current_user_id)):
    prefs = get_user_preferences(user_id)
    if prefs is None:
        raise HTTPException(status_code=404, detail="preferences_not_found")
    return {"preferences": prefs}


@app.put("/v1/user/preferences")
def user_preferences_put(req: PreferencesUpdateRequest, user_id: str = Depends(get_current_user_id)):
    update_dict = req.dict(exclude_unset=True)
    prefs = update_user_preferences(user_id, update_dict)
    if prefs is None:
        raise HTTPException(status_code=400, detail="update_preferences_failed")
    return {"preferences": prefs}


@app.get("/v1/user/follows")
def user_follows_get(user_id: str = Depends(get_current_user_id)):
    follows = get_user_follows(user_id)
    return {"follows": follows}


@app.post("/v1/user/follows")
def user_follows_post(req: FollowRequest, user_id: str = Depends(get_current_user_id)):
    success = follow_entity(
        user_id,
        req.entityType,
        req.entityId,
        req.notificationLevel,
    )
    if not success:
        raise HTTPException(status_code=400, detail="follow_failed")
    return {"status": "success"}


@app.delete("/v1/user/follows")
def user_follows_delete(entityType: str, entityId: str, user_id: str = Depends(get_current_user_id)):
    success = unfollow_entity(user_id, entityType, entityId)
    if not success:
        raise HTTPException(status_code=400, detail="unfollow_failed")
    return {"status": "success"}


@app.delete("/v1/user/account")
def user_account_delete(user_id: str = Depends(get_current_user_id)):
    success = delete_user_account(user_id)
    if not success:
        raise HTTPException(status_code=404, detail="user_not_found")
    return {"status": "success", "message": "user_account_deleted_successfully"}
