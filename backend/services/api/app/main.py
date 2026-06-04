"""
Esports360 API — main.py
Entry point: registers all routers and global middleware.
"""
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from esports360.config import get_settings
from esports360.object_storage import using_minio

from .routers import health, meta, matches, teams, tournaments, discover, auth, user, websocket

settings = get_settings()

app = FastAPI(
    title="Esports360 API",
    version="0.2.0",
    description="Provider-neutral backend for Esports360.",
)

# ── Media serving ──────────────────────────────────────────────────────────────
if using_minio():
    from esports360.object_storage import get_object_bytes

    @app.get("/media/{storage_key:path}")
    def media_object(storage_key: str):
        from fastapi import HTTPException
        from fastapi.responses import Response
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

# ── Routers ────────────────────────────────────────────────────────────────────
app.include_router(health.router)
app.include_router(meta.router)
app.include_router(matches.router)
app.include_router(teams.router)
app.include_router(tournaments.router)
app.include_router(discover.router)
app.include_router(auth.router)
app.include_router(user.router)
app.include_router(websocket.router)   # Z2: WebSocket proxy
