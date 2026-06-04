#!/usr/bin/env node
"use strict";

const crypto = require("crypto");
const { Pool } = require("pg");
const SteamUser = require("steam-user");
const GlobalOffensive = require("globaloffensive");

const POLL_SECONDS = parseInt(process.env.CS2_GC_POLL_SECONDS || "20", 10);
const SENTRY_DIR = process.env.STEAM_SENTRY_DIR || "/data/steam-sentry";
const username = process.env.STEAM_USERNAME;
const password = process.env.STEAM_PASSWORD;
const sharedSecret = process.env.STEAM_SHARED_SECRET || undefined;
const guardCode = process.env.STEAM_GUARD_CODE || undefined;
const rawDbUrl = process.env.DATABASE_URL || "";
const connectionString = rawDbUrl.replace("postgresql+psycopg://", "postgresql://");

if (!username || !password) {
  console.error("CS2 GC Collector: missing STEAM_USERNAME/STEAM_PASSWORD; service cannot start.");
  process.exit(10);
}
if (!connectionString) {
  console.error("CS2 GC Collector: DATABASE_URL is missing.");
  process.exit(11);
}

const pool = new Pool({ connectionString });
const client = new SteamUser({ dataDirectory: SENTRY_DIR, autoRelogin: true });
const csgo = new GlobalOffensive(client);

let providerId = null;
let gameId = null;
let pollTimer = null;
let lastRequestAt = 0;

function safePlain(value) {
  return JSON.parse(JSON.stringify(value, (_key, val) => {
    if (typeof val === "bigint") return val.toString();
    if (val && typeof val === "object" && val.low !== undefined && val.high !== undefined && typeof val.toString === "function") {
      return val.toString();
    }
    if (Buffer.isBuffer(val)) return val.toString("hex");
    return val;
  }));
}

function str(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === "object" && typeof value.toString === "function") return value.toString();
  return String(value);
}

function hashPayload(payload) {
  return crypto.createHash("sha256").update(JSON.stringify(payload)).digest("hex");
}

async function initDb() {
  const c = await pool.connect();
  try {
    await c.query("BEGIN");
    const provider = await c.query(`
      INSERT INTO providers (code, name, website_url, status, capabilities, commercial_notes)
      VALUES ('steam_gc', 'Steam Game Coordinator', 'https://developer.valvesoftware.com', 'active',
              '{"live_matches": true, "round_stats": true, "watchable_matches": true}'::jsonb,
              'Valve CS2 Game Coordinator via steam-user/globaloffensive')
      ON CONFLICT (code) DO UPDATE SET
        status = 'active',
        capabilities = providers.capabilities || excluded.capabilities,
        updated_at = now()
      RETURNING id
    `);
    providerId = provider.rows[0].id;

    const game = await c.query(`
      INSERT INTO games (code, name, short_name, publisher, metadata)
      VALUES ('cs2', 'Counter-Strike 2', 'CS2', 'Valve', '{"source":"steam_gc"}'::jsonb)
      ON CONFLICT (code) DO UPDATE SET updated_at = now()
      RETURNING id
    `);
    gameId = game.rows[0].id;
    await c.query("COMMIT");
    console.log("CS2 GC Collector: DB ready provider=" + providerId + " game=" + gameId);
  } catch (e) {
    await c.query("ROLLBACK");
    throw e;
  } finally {
    c.release();
  }
}

function extractSummary(raw) {
  const watch = raw.watchablematchinfo || {};
  const stats = raw.roundstats_legacy || (Array.isArray(raw.roundstatsall) && raw.roundstatsall.length ? raw.roundstatsall[raw.roundstatsall.length - 1] : {}) || {};
  const matchId = str(raw.matchid || watch.match_id || stats.reservationid || watch.reservation_id || watch.server_id);
  const mapName = stats.map || watch.game_map || null;
  const teamScores = Array.isArray(stats.team_scores) ? stats.team_scores : [];
  const roundNumber = Number.isFinite(stats.round) ? stats.round : null;
  const matchDuration = Number.isFinite(stats.match_duration) ? stats.match_duration : null;
  const maxRounds = Number.isFinite(stats.max_rounds) ? stats.max_rounds : null;
  return { matchId, mapName, teamScores, roundNumber, matchDuration, maxRounds, watch, stats };
}

async function storeMatch(rawMatch) {
  const raw = safePlain(rawMatch);
  const { matchId, mapName, teamScores, roundNumber, matchDuration, maxRounds, watch, stats } = extractSummary(raw);
  if (!matchId) return;

  const slug = `steam-gc-${matchId}`.toLowerCase();
  const name = `CS2 GC Live ${mapName || "match"} ${matchId}`;
  const payloadHash = hashPayload(raw);
  const state = {
    source: "steam_gc",
    external_match_id: matchId,
    map: mapName,
    round: roundNumber,
    max_rounds: maxRounds,
    team_scores: teamScores,
    match_duration: matchDuration,
    spectators_count: stats.spectators_count ?? null,
    spectators_count_tv: stats.spectators_count_tv ?? watch.tv_spectators ?? null,
    matchtime: raw.matchtime ?? null,
    watchable: watch,
  };

  const c = await pool.connect();
  try {
    await c.query("BEGIN");
    const matchRes = await c.query(`
      INSERT INTO matches (game_id, name, slug, status, last_provider_update_at, metadata)
      VALUES ($1, $2, $3, 'live', now(), $4::jsonb)
      ON CONFLICT (slug) DO UPDATE SET
        status = 'live',
        name = excluded.name,
        last_provider_update_at = now(),
        metadata = matches.metadata || excluded.metadata,
        updated_at = now()
      RETURNING id
    `, [gameId, name, slug, JSON.stringify({ steam_gc: state })]);
    const matchDbId = matchRes.rows[0].id;

    await c.query(`
      INSERT INTO provider_entity_map (provider_id, entity_type, entity_id, external_id, external_slug, is_primary, metadata)
      VALUES ($1, 'match', $2, $3, $4, true, $5::jsonb)
      ON CONFLICT (provider_id, entity_type, external_id) DO UPDATE SET
        entity_id = excluded.entity_id,
        external_slug = excluded.external_slug,
        last_seen_at = now(),
        metadata = provider_entity_map.metadata || excluded.metadata
    `, [providerId, matchDbId, matchId, slug, JSON.stringify({ source: "steam_gc" })]);

    const gameRes = await c.query(`
      INSERT INTO match_games (match_id, game_number, map_name, status, duration_seconds, metadata)
      VALUES ($1, 1, $2, 'live', $3, $4::jsonb)
      ON CONFLICT (match_id, game_number) DO UPDATE SET
        map_name = coalesce(excluded.map_name, match_games.map_name),
        status = 'live',
        duration_seconds = coalesce(excluded.duration_seconds, match_games.duration_seconds),
        metadata = match_games.metadata || excluded.metadata,
        updated_at = now()
      RETURNING id
    `, [matchDbId, mapName, matchDuration, JSON.stringify({ steam_gc: { external_match_id: matchId, round: roundNumber, max_rounds: maxRounds } })]);
    const matchGameId = gameRes.rows[0].id;

    await c.query(`
      INSERT INTO live_match_states (match_id, status, clock_seconds, state, source_provider_id, provider_freshness_at, updated_at)
      VALUES ($1, 'live', $2, $3::jsonb, $4, now(), now())
      ON CONFLICT (match_id) DO UPDATE SET
        status = 'live',
        clock_seconds = excluded.clock_seconds,
        state = live_match_states.state || excluded.state,
        source_provider_id = excluded.source_provider_id,
        provider_freshness_at = now(),
        updated_at = now()
    `, [matchDbId, matchDuration, JSON.stringify(state), providerId]);

    for (let i = 0; i < teamScores.length; i++) {
      const value = Number(teamScores[i] || 0);
      const latest = await c.query(`
        SELECT value, recorded_at FROM match_scores
        WHERE match_id = $1 AND score_type = 'round' AND metadata->>'source' = 'steam_gc' AND metadata->>'team_index' = $2
        ORDER BY recorded_at DESC LIMIT 1
      `, [matchDbId, String(i)]);
      if (latest.rows.length && Number(latest.rows[0].value) === value) {
        const fresh = await c.query("SELECT now() - $1::timestamptz < interval '20 seconds' AS fresh", [latest.rows[0].recorded_at]);
        if (fresh.rows[0].fresh) continue;
      }
      await c.query(`
        INSERT INTO match_scores (match_id, score_type, game_number, value, recorded_at, metadata)
        VALUES ($1, 'round', 1, $2, now(), $3::jsonb)
      `, [matchDbId, value, JSON.stringify({ source: "steam_gc", team_index: String(i), external_match_id: matchId, round: roundNumber })]);
    }

    await c.query(`
      INSERT INTO provider_payloads (provider_id, feed_type, entity_type, entity_id, external_id, endpoint, payload, payload_hash)
      VALUES ($1, 'steam_gc_live_matches', 'match', $2, $3, 'requestLiveGames', $4::jsonb, $5)
      ON CONFLICT (provider_id, feed_type, external_id, payload_hash) DO NOTHING
    `, [providerId, matchDbId, matchId, JSON.stringify(raw), payloadHash]);

    await c.query(`
      INSERT INTO live_events (match_id, match_game_id, sequence, event_type, occurred_at, source_provider_id, external_event_id, payload)
      VALUES (
        $1, $2,
        (SELECT COALESCE(MAX(sequence), 0) + 1 FROM live_events WHERE match_id = $1),
        'steam_gc_snapshot', now(), $3, $4, $5::jsonb
      )
      ON CONFLICT (match_id, sequence) DO NOTHING
    `, [matchDbId, matchGameId, providerId, `${matchId}:${Date.now()}`, JSON.stringify(state)]);

    await c.query("COMMIT");
  } catch (e) {
    await c.query("ROLLBACK");
    console.error("CS2 GC Collector: store failed for match " + matchId + ": " + e.message);
  } finally {
    c.release();
  }
}

async function requestLiveGames() {
  lastRequestAt = Date.now();
  try {
    csgo.requestLiveGames();
    console.log("CS2 GC Collector: requested live games");
  } catch (e) {
    console.error("CS2 GC Collector: requestLiveGames failed: " + e.message);
  }
}

csgo.on("connectedToGC", () => {
  console.log("CS2 GC Collector: connectedToGC");
  requestLiveGames();
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = setInterval(requestLiveGames, Math.max(5, POLL_SECONDS) * 1000);
});

csgo.on("disconnectedFromGC", (reason) => {
  console.log("CS2 GC Collector: disconnectedFromGC reason=" + reason);
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = null;
});

csgo.on("matchList", async (matches) => {
  const list = Array.isArray(matches) ? matches : [];
  console.log(`CS2 GC Collector: matchList received ${list.length} matches`);
  for (const match of list) await storeMatch(match);
});

client.on("loggedOn", () => {
  console.log("CS2 GC Collector: logged on; launching CS2 app 730");
  client.gamesPlayed([730], true);
});

client.on("error", (err) => {
  console.error("CS2 GC Collector: Steam error: " + (err.message || err));
});

client.on("steamGuard", (domain, callback) => {
  if (guardCode) return callback(guardCode);
  if (sharedSecret) return callback(SteamUser.generateAuthCode(sharedSecret));
  console.error("CS2 GC Collector: Steam Guard required but no STEAM_GUARD_CODE/STEAM_SHARED_SECRET provided.");
  process.exit(12);
});

process.on("SIGTERM", async () => {
  console.log("CS2 GC Collector: SIGTERM");
  try { client.logOff(); } catch (_) {}
  await pool.end();
  process.exit(0);
});

(async () => {
  await initDb();
  console.log(`CS2 GC Collector: starting poll=${POLL_SECONDS}s sentry=${SENTRY_DIR}`);
  const loginOpts = { accountName: username, password, rememberPassword: true };
  if (guardCode) loginOpts.twoFactorCode = guardCode;
  else if (sharedSecret) loginOpts.twoFactorCode = SteamUser.generateAuthCode(sharedSecret);
  client.logOn(loginOpts);
})();
