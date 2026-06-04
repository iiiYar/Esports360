# Esports360 Backend

Backend stack for Esports360.

Current services:

- FastAPI API container
- Worker container
- PostgreSQL container
- Redis container

The database schema is created through files in `db/schema`.

The worker can poll PandaScore when these env vars are set:

```env
PANDASCORE_TOKEN=...
PANDASCORE_SYNC_ENABLED=true
PANDASCORE_SYNC_ON_START=true
```

Keep provider tokens on the server only. Do not put them in the iOS app.

## Ports

| Service | Container Port | Host Port | Exposure |
|---|---:|---:|---|
| API | 8000 | 8010 | LAN |
| PostgreSQL | 5432 | 5432 | localhost only |
| Redis | 6379 | 6379 | localhost only |
| MinIO S3 API | 9000 | 9000 | LAN |
| MinIO Console | 9001 | 9011 | LAN |

Reserved for later:

| Service | Port |
|---|---:|
| HTTP reverse proxy | 80 |
| HTTPS reverse proxy | 443 |
| Metrics | 9100 |

## Commands

```bash
docker compose up -d --build
docker compose ps
curl http://localhost:8010/health
```

## API Endpoints

```text
GET /health
GET /v1/meta/ports
GET /v1/matches/today
GET /v1/matches/live
GET /v1/matches/upcoming
GET /v1/games
GET /v1/matches/{id}
GET /v1/teams/{id}
GET /v1/tournaments/{id}
```

## Ingestion Flow

```text
PandaScore REST
  -> provider_payloads raw JSON
  -> provider_entity_map external IDs
  -> games/leagues/series/tournaments/teams/players/matches
  -> iOS reads only Esports360 API DTOs
```

## Image Pipeline

Team logos, generated game logos, and priority-team player portraits are processed into media variants.

Storage:

```text
Object storage: MinIO
Bucket: esports360-media
Public path: /media/{entity}/{id}/{role}/{variant}.png
MinIO API: http://server:9000
MinIO Console: http://server:9011
```

Variants:

```text
xs: 64x64
sm: 128x128
md: 256x256
lg: 512x512
```

Database:

```text
media_assets
entity_media
media_asset_variants
image_ingestion_logs
```

The API returns both:

```json
{
  "imageUrl": "/media/team/{id}/logo/sm.png",
  "image": {
    "sourceUrl": "https://external-source/image.png",
    "variants": {
      "xs": { "url": "/media/...", "width": 64, "height": 64, "format": "png" },
      "sm": { "url": "/media/...", "width": 128, "height": 128, "format": "png" },
      "md": { "url": "/media/...", "width": 256, "height": 256, "format": "png" },
      "lg": { "url": "/media/...", "width": 512, "height": 512, "format": "png" }
    }
  }
}
```

The API proxies `/media/...` through MinIO, so iOS keeps using the same media URLs even if storage later moves to S3, Cloudflare R2, or another S3-compatible backend.

Priority rosters are synced from PandaScore every 12 hours by default:

```env
PANDASCORE_ROSTER_INTERVAL_HOURS=12
PANDASCORE_ROSTER_TEAM_LIMIT=10
PANDASCORE_PRIORITY_TEAM_IDS=133868,138068,130861,129571,126061,128538,136396,135125,137057,135679
```

Current image roles:

```text
team/logo
game/logo
player/portrait
```

Game logos are DB-driven through `games.metadata.media.logo_url`.
The first production sources are Simple Icons SVGs, Steam store assets, selected Wikimedia game assets, and Arcticons for MLBB.
Generated logos remain as a fallback when no source URL exists.
