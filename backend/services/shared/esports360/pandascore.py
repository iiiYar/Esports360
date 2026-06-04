from datetime import date, timedelta
from typing import Any

import httpx


class PandaScoreProvider:
    def __init__(self, token: str, base_url: str = "https://api.pandascore.co") -> None:
        if not token:
            raise ValueError("PANDASCORE_TOKEN is required")
        self.base_url = base_url.rstrip("/")
        self.headers = {"Authorization": f"Bearer {token}"}

    async def _get(self, path: str, params: dict[str, Any] | None = None) -> list[dict[str, Any]]:
        async with httpx.AsyncClient(base_url=self.base_url, headers=self.headers, timeout=30) as client:
            response = await client.get(path, params=params)
            response.raise_for_status()
            data = response.json()
            if not isinstance(data, list):
                raise ValueError(f"PandaScore endpoint {path} returned non-list JSON")
            return data

    async def videogames(self) -> list[dict[str, Any]]:
        return await self._get("/videogames", {"per_page": 100})

    async def team(self, team_id_or_slug: str | int) -> dict[str, Any]:
        async with httpx.AsyncClient(base_url=self.base_url, headers=self.headers, timeout=30) as client:
            response = await client.get(f"/teams/{team_id_or_slug}")
            response.raise_for_status()
            data = response.json()
            if not isinstance(data, dict):
                raise ValueError(f"PandaScore endpoint /teams/{team_id_or_slug} returned non-object JSON")
            return data

    async def running_matches(self) -> list[dict[str, Any]]:
        return await self._get("/matches/running", {"per_page": 100})

    async def upcoming_matches(self, days: int = 7) -> list[dict[str, Any]]:
        today = date.today()
        end = today + timedelta(days=days)
        return await self._get(
            "/matches/upcoming",
            {
                "per_page": 100,
                "range[scheduled_at]": f"{today.isoformat()},{end.isoformat()}",
            },
        )

    async def today_matches(self) -> list[dict[str, Any]]:
        today = date.today()
        tomorrow = today + timedelta(days=1)
        return await self._get(
            "/matches",
            {
                "per_page": 100,
                "range[scheduled_at]": f"{today.isoformat()},{tomorrow.isoformat()}",
            },
        )

    async def match_details(self, match_id: str | int) -> dict[str, Any]:
        """Fetch a single match by PandaScore ID. Used for reconciliation."""
        async with httpx.AsyncClient(base_url=self.base_url, headers=self.headers, timeout=15) as client:
            response = await client.get(f"/matches/{match_id}")
            response.raise_for_status()
            data = response.json()
            if not isinstance(data, dict):
                raise ValueError(f"PandaScore /matches/{match_id} returned non-object JSON")
            return data

    async def past_matches(self, hours: int = 6) -> list[dict[str, Any]]:
        """Fetch recently completed matches (last N hours)."""
        return await self._get(
            "/matches/past",
            {"per_page": 50},
        )
