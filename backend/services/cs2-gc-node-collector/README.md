# CS2 GC Node Collector

خدمة Node مستقلة تسحب live matches من CS2 Steam Game Coordinator كل 20 ثانية وتكتب في قاعدة Esports360.

## يكتب في الجداول

- `providers`: يسجل provider باسم `steam_gc`.
- `matches`: ينشئ/يحدث مباريات مباشرة synthetic باسم `CS2 GC Live ...` مع slug `steam-gc-<matchid>`.
- `provider_entity_map`: يربط `steam_gc` external match id بالمباراة.
- `provider_payloads`: يخزن raw GC payload في feed `steam_gc_live_matches`.
- `live_match_states`: يخزن `round`, `team_scores`, `match_duration`, `map`, `spectators`.
- `match_games`: يخزن map/game الحالي.
- `match_scores`: snapshots لتقدم الجولات لكل team index.
- `live_events`: snapshot event لكل تحديث.

## التشغيل

لا تلصق كلمة مرور Steam في الشات. شغّل من السيرفر أو أضف المتغيرات في `.env` محلياً:

```bash
cd /opt/esports360
STEAM_USERNAME=xxx STEAM_PASSWORD='***' STEAM_GUARD_CODE=12345 \
  docker compose --profile gc up -d cs2-gc-node-collector
```

أو أضف في `.env`:

```env
STEAM_USERNAME=xxx
STEAM_PASSWORD=***
STEAM_SHARED_SECRET=optional
CS2_GC_POLL_SECONDS=20
```

ثم:

```bash
docker compose --profile gc up -d cs2-gc-node-collector
```
