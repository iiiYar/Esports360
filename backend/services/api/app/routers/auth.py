"""
Router: /v1/auth/*
Handles sign-up and login. Returns JWT — must be stored in Keychain on client, never UserDefaults.
"""
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
import bcrypt
import jwt

from esports360.config import get_settings
from esports360.queries import create_user_account, get_user_account_by_email

router   = APIRouter(prefix="/v1/auth", tags=["Auth"])
settings = get_settings()

_JWT_ALGORITHM  = "HS256"
_TOKEN_TTL_DAYS = 30


def _mint_token(user_id: str) -> str:
    exp = datetime.now(timezone.utc) + timedelta(days=_TOKEN_TTL_DAYS)
    return jwt.encode(
        {"sub": user_id, "exp": exp},
        settings.jwt_secret_key,
        algorithm=_JWT_ALGORITHM,
    )


class AuthRequest(BaseModel):
    email:    str
    password: str


@router.post("/signup", status_code=status.HTTP_201_CREATED)
def signup(req: AuthRequest):
    if not req.email or "@" not in req.email or len(req.password) < 6:
        raise HTTPException(400, detail="invalid_email_or_password_length")

    hashed = bcrypt.hashpw(req.password.encode(), bcrypt.gensalt()).decode()
    user   = create_user_account(req.email, hashed)
    if not user:
        raise HTTPException(400, detail="email_already_registered")

    return {"token": _mint_token(user["id"]), "user": user}


@router.post("/login")
def login(req: AuthRequest):
    user = get_user_account_by_email(req.email)
    if not user or not user.get("hashed_password"):
        raise HTTPException(400, detail="invalid_credentials")

    if not bcrypt.checkpw(req.password.encode(), user["hashed_password"].encode()):
        raise HTTPException(400, detail="invalid_credentials")

    user.pop("hashed_password", None)
    return {"token": _mint_token(user["id"]), "user": user}
