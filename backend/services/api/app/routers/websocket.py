"""
Router: /v1/ws/*
WebSocket proxy — forwards PandaScore Live stream to authenticated iOS clients.
The iOS app connects with its JWT token, the backend verifies it then
establishes the upstream PandaScore WSS connection and relays every frame.
"""
import asyncio
import json
import logging

import websockets
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from esports360.config import get_settings

logger   = logging.getLogger(__name__)
router   = APIRouter(prefix="/v1/ws", tags=["WebSocket"])
settings = get_settings()

_JWT_ALGORITHM  = "HS256"
_PING_INTERVAL  = 25   # seconds — keeps iOS NAT / CDN connection alive


def _verify_token(token: str) -> str | None:
    """Returns user_id if token is valid, None otherwise."""
    try:
        import jwt
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[_JWT_ALGORITHM])
        return payload.get("sub")
    except Exception:
        return None


@router.websocket("/matches/{match_id}")
async def ws_match_live(websocket: WebSocket, match_id: str, token: str = ""):
    """
    Proxy endpoint consumed by LiveScoreWebSocketManager.swift.
    Flow:
      1. Verify JWT from ?token= query param
      2. Accept the WebSocket
      3. Open upstream PandaScore WSS for this match
      4. Forward every upstream message to the iOS client
      5. Inject a keepalive ping every 25 s to prevent iOS disconnects
    """
    user_id = _verify_token(token)
    if not user_id:
        await websocket.close(code=4001)   # Unauthorized
        return

    await websocket.accept()
    logger.info("WS connect  match=%s user=%s", match_id, user_id)

    upstream_url = (
        f"wss://live.pandascore.co/matches/{match_id}"
        f"?token={settings.pandascore_token}"
    )

    try:
        async with websockets.connect(
            upstream_url,
            ping_interval=None,   # we handle pings ourselves
            open_timeout=10,
            close_timeout=5,
        ) as upstream:

            async def _forward():
                """Relay PandaScore frames → iOS client."""
                try:
                    async for raw in upstream:
                        await websocket.send_text(
                            raw if isinstance(raw, str) else raw.decode()
                        )
                except WebSocketDisconnect:
                    pass
                except Exception as exc:
                    logger.warning("WS forward error match=%s: %s", match_id, exc)

            async def _keepalive():
                """Ping client every 25 s to keep the connection alive."""
                while True:
                    await asyncio.sleep(_PING_INTERVAL)
                    try:
                        await websocket.send_text(json.dumps({"type": "ping"}))
                    except Exception:
                        return

            await asyncio.gather(_forward(), _keepalive(), return_exceptions=True)

    except WebSocketDisconnect:
        logger.info("WS disconnect match=%s user=%s", match_id, user_id)
    except Exception as exc:
        logger.error("WS upstream error match=%s: %s", match_id, exc)
    finally:
        try:
            await websocket.close()
        except Exception:
            pass
