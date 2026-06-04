"""
Router: /v1/user/*
All routes require valid JWT Bearer token.
"""
from fastapi import APIRouter, Depends, HTTPException, Header, status
from pydantic import BaseModel
import jwt

from esports360.config import get_settings
from esports360.queries import (
    get_user_account_by_id,
    delete_user_account,
    get_user_preferences,
    update_user_preferences,
    get_user_follows,
    follow_entity,
    unfollow_entity,
)

router   = APIRouter(prefix="/v1/user", tags=["User"])
settings = get_settings()

_JWT_ALGORITHM = "HS256"


# ── Auth dependency ────────────────────────────────────────────────────────────
def get_current_user_id(authorization: str = Header(None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="missing_or_invalid_token")
    token = authorization.split(" ", 1)[1]
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[_JWT_ALGORITHM])
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="invalid_token_payload")
        return user_id
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="token_expired")
    except jwt.PyJWTError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="invalid_token")


# ── Pydantic models ────────────────────────────────────────────────────────────
class PreferencesUpdateRequest(BaseModel):
    language:             str  | None = None
    calendarPreference:   str  | None = None
    saudiFanMode:         bool | None = None
    notificationsEnabled: bool | None = None
    notifMatchStart:      bool | None = None
    notifScoreChange:     bool | None = None
    notifMatchEnd:        bool | None = None
    notifRosterChange:    bool | None = None
    notifStreamLive:      bool | None = None
    notifFantasyRemind:   bool | None = None


class FollowRequest(BaseModel):
    entityType:        str
    entityId:          str
    notificationLevel: str = "normal"


# ── Routes ─────────────────────────────────────────────────────────────────────
@router.get("/profile")
def user_profile(user_id: str = Depends(get_current_user_id)):
    user = get_user_account_by_id(user_id)
    if not user:
        raise HTTPException(404, detail="user_not_found")
    return {"user": user}


@router.get("/preferences")
def get_preferences(user_id: str = Depends(get_current_user_id)):
    prefs = get_user_preferences(user_id)
    if prefs is None:
        raise HTTPException(404, detail="preferences_not_found")
    return {"preferences": prefs}


@router.put("/preferences")
def update_preferences(
    req: PreferencesUpdateRequest,
    user_id: str = Depends(get_current_user_id),
):
    prefs = update_user_preferences(user_id, req.dict(exclude_unset=True))
    if prefs is None:
        raise HTTPException(400, detail="update_preferences_failed")
    return {"preferences": prefs}


@router.get("/follows")
def get_follows(user_id: str = Depends(get_current_user_id)):
    return {"follows": get_user_follows(user_id)}


@router.post("/follows")
def add_follow(req: FollowRequest, user_id: str = Depends(get_current_user_id)):
    if not follow_entity(user_id, req.entityType, req.entityId, req.notificationLevel):
        raise HTTPException(400, detail="follow_failed")
    return {"status": "success"}


@router.delete("/follows")
def remove_follow(
    entityType: str,
    entityId:   str,
    user_id: str = Depends(get_current_user_id),
):
    if not unfollow_entity(user_id, entityType, entityId):
        raise HTTPException(400, detail="unfollow_failed")
    return {"status": "success"}


@router.delete("/account")
def delete_account(user_id: str = Depends(get_current_user_id)):
    if not delete_user_account(user_id):
        raise HTTPException(404, detail="user_not_found")
    return {"status": "success", "message": "user_account_deleted_successfully"}
