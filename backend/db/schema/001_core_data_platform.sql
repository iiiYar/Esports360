-- Esports360 Core Data Platform
-- Provider-neutral PostgreSQL schema for esports catalog, competition,
-- live data, stats, media, users, notifications, fantasy, AI, and sync.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS providers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code CITEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  website_url TEXT,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'paused', 'disabled', 'pending')),
  capabilities JSONB NOT NULL DEFAULT '{}'::jsonb,
  commercial_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER providers_set_updated_at
BEFORE UPDATE ON providers
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS regions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code CITEXT NOT NULL UNIQUE,
  name_en TEXT NOT NULL,
  name_ar TEXT,
  parent_region_id UUID REFERENCES regions(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER regions_set_updated_at
BEFORE UPDATE ON regions
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS games (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code CITEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  short_name TEXT,
  genre TEXT,
  publisher TEXT,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'coming_soon')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER games_set_updated_at
BEFORE UPDATE ON games
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS media_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_type TEXT NOT NULL
    CHECK (asset_type IN ('image', 'video', 'stream', 'vod', 'audio', 'document')),
  source TEXT,
  url TEXT,
  storage_key TEXT,
  mime_type TEXT,
  width INT CHECK (width IS NULL OR width > 0),
  height INT CHECK (height IS NULL OR height > 0),
  duration_seconds INT CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
  checksum TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (url IS NOT NULL OR storage_key IS NOT NULL)
);

CREATE TRIGGER media_assets_set_updated_at
BEFORE UPDATE ON media_assets
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS entity_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  media_asset_id UUID NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  locale TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (entity_type, entity_id, media_asset_id, role)
);

CREATE INDEX IF NOT EXISTS idx_entity_media_entity_role
ON entity_media(entity_type, entity_id, role);

CREATE INDEX IF NOT EXISTS idx_media_assets_type
ON media_assets(asset_type);

CREATE TABLE IF NOT EXISTS game_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  media_asset_id UUID NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (game_id, role, media_asset_id)
);

CREATE TABLE IF NOT EXISTS teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  primary_game_id UUID REFERENCES games(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  short_name TEXT,
  slug CITEXT,
  country_code CHAR(2),
  region_id UUID REFERENCES regions(id) ON DELETE SET NULL,
  founded_year INT CHECK (founded_year IS NULL OR founded_year >= 1970),
  is_saudi BOOLEAN NOT NULL DEFAULT false,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'disbanded', 'unknown')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (slug)
);

CREATE TRIGGER teams_set_updated_at
BEFORE UPDATE ON teams
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_teams_primary_game_name
ON teams(primary_game_id, name);

CREATE INDEX IF NOT EXISTS idx_teams_saudi
ON teams(is_saudi)
WHERE is_saudi = true;

CREATE TABLE IF NOT EXISTS team_aliases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  alias CITEXT NOT NULL,
  locale TEXT,
  source TEXT,
  confidence NUMERIC(4, 3) NOT NULL DEFAULT 1.000
    CHECK (confidence >= 0 AND confidence <= 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (team_id, alias)
);

CREATE INDEX IF NOT EXISTS idx_team_aliases_alias
ON team_aliases(alias);

CREATE TABLE IF NOT EXISTS players (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  primary_game_id UUID REFERENCES games(id) ON DELETE SET NULL,
  handle CITEXT NOT NULL,
  real_name TEXT,
  slug CITEXT,
  country_code CHAR(2),
  birth_date DATE,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'retired', 'unknown')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (slug)
);

CREATE TRIGGER players_set_updated_at
BEFORE UPDATE ON players
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_players_game_handle
ON players(primary_game_id, handle);

CREATE TABLE IF NOT EXISTS player_aliases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  alias CITEXT NOT NULL,
  locale TEXT,
  source TEXT,
  confidence NUMERIC(4, 3) NOT NULL DEFAULT 1.000
    CHECK (confidence >= 0 AND confidence <= 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (player_id, alias)
);

CREATE INDEX IF NOT EXISTS idx_player_aliases_alias
ON player_aliases(alias);

CREATE TABLE IF NOT EXISTS team_rosters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  game_id UUID REFERENCES games(id) ON DELETE SET NULL,
  name TEXT,
  active_from DATE,
  active_to DATE,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (active_to IS NULL OR active_from IS NULL OR active_to >= active_from)
);

CREATE TRIGGER team_rosters_set_updated_at
BEFORE UPDATE ON team_rosters
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_team_rosters_team_game
ON team_rosters(team_id, game_id);

CREATE TABLE IF NOT EXISTS team_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  roster_id UUID REFERENCES team_rosters(id) ON DELETE SET NULL,
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  game_id UUID REFERENCES games(id) ON DELETE SET NULL,
  role TEXT,
  jersey_name TEXT,
  active_from DATE,
  active_to DATE,
  is_starter BOOLEAN,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (active_to IS NULL OR active_from IS NULL OR active_to >= active_from)
);

CREATE TRIGGER team_memberships_set_updated_at
BEFORE UPDATE ON team_memberships
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_team_memberships_team_active
ON team_memberships(team_id, active_to);

CREATE INDEX IF NOT EXISTS idx_team_memberships_player_active
ON team_memberships(player_id, active_to);

CREATE UNIQUE INDEX IF NOT EXISTS uq_team_memberships_open
ON team_memberships(team_id, player_id, game_id)
WHERE active_to IS NULL;

CREATE TABLE IF NOT EXISTS venues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  city TEXT,
  country_code CHAR(2),
  timezone TEXT,
  latitude NUMERIC(9, 6),
  longitude NUMERIC(9, 6),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER venues_set_updated_at
BEFORE UPDATE ON venues
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS leagues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID REFERENCES games(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  slug CITEXT,
  region_id UUID REFERENCES regions(id) ON DELETE SET NULL,
  tier TEXT,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'archived', 'unknown')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (slug)
);

CREATE TRIGGER leagues_set_updated_at
BEFORE UPDATE ON leagues
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_leagues_game_region
ON leagues(game_id, region_id);

CREATE TABLE IF NOT EXISTS series (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  league_id UUID REFERENCES leagues(id) ON DELETE SET NULL,
  game_id UUID REFERENCES games(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  slug CITEXT,
  year INT,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled', 'running', 'completed', 'cancelled', 'unknown')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (slug),
  CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at >= starts_at)
);

CREATE TRIGGER series_set_updated_at
BEFORE UPDATE ON series
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_series_league_year
ON series(league_id, year);

CREATE TABLE IF NOT EXISTS tournaments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  series_id UUID REFERENCES series(id) ON DELETE SET NULL,
  league_id UUID REFERENCES leagues(id) ON DELETE SET NULL,
  game_id UUID REFERENCES games(id) ON DELETE SET NULL,
  venue_id UUID REFERENCES venues(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  slug CITEXT,
  format TEXT,
  prize_pool TEXT,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled', 'running', 'completed', 'cancelled', 'postponed', 'unknown')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (slug),
  CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at >= starts_at)
);

CREATE TRIGGER tournaments_set_updated_at
BEFORE UPDATE ON tournaments
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_tournaments_game_starts
ON tournaments(game_id, starts_at DESC);

CREATE INDEX IF NOT EXISTS idx_tournaments_status
ON tournaments(status, starts_at);

CREATE TABLE IF NOT EXISTS tournament_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
  player_id UUID REFERENCES players(id) ON DELETE SET NULL,
  seed INT,
  invite_type TEXT,
  status TEXT NOT NULL DEFAULT 'confirmed'
    CHECK (status IN ('invited', 'confirmed', 'qualified', 'withdrawn', 'unknown')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (team_id IS NOT NULL OR player_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_tournament_participants_tournament
ON tournament_participants(tournament_id, seed);

CREATE TABLE IF NOT EXISTS tournament_stages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  stage_type TEXT NOT NULL
    CHECK (stage_type IN ('group', 'swiss', 'round_robin', 'playoff', 'bracket', 'final', 'other')),
  sort_order INT NOT NULL DEFAULT 0,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at >= starts_at)
);

CREATE TRIGGER tournament_stages_set_updated_at
BEFORE UPDATE ON tournament_stages
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_tournament_stages_tournament_order
ON tournament_stages(tournament_id, sort_order);

CREATE TABLE IF NOT EXISTS tournament_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stage_id UUID NOT NULL REFERENCES tournament_stages(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (stage_id, name)
);

CREATE TABLE IF NOT EXISTS standings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID REFERENCES tournaments(id) ON DELETE CASCADE,
  stage_id UUID REFERENCES tournament_stages(id) ON DELETE CASCADE,
  group_id UUID REFERENCES tournament_groups(id) ON DELETE CASCADE,
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  rank INT,
  points NUMERIC(10, 3) NOT NULL DEFAULT 0,
  wins INT NOT NULL DEFAULT 0 CHECK (wins >= 0),
  losses INT NOT NULL DEFAULT 0 CHECK (losses >= 0),
  draws INT NOT NULL DEFAULT 0 CHECK (draws >= 0),
  maps_for INT NOT NULL DEFAULT 0 CHECK (maps_for >= 0),
  maps_against INT NOT NULL DEFAULT 0 CHECK (maps_against >= 0),
  rounds_for INT NOT NULL DEFAULT 0 CHECK (rounds_for >= 0),
  rounds_against INT NOT NULL DEFAULT 0 CHECK (rounds_against >= 0),
  tiebreakers JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (stage_id, group_id, team_id)
);

CREATE INDEX IF NOT EXISTS idx_standings_scope_rank
ON standings(stage_id, group_id, rank);

CREATE TABLE IF NOT EXISTS bracket_nodes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  stage_id UUID REFERENCES tournament_stages(id) ON DELETE CASCADE,
  parent_node_id UUID REFERENCES bracket_nodes(id) ON DELETE SET NULL,
  bracket_side TEXT,
  round_number INT NOT NULL DEFAULT 1,
  match_order INT NOT NULL DEFAULT 0,
  label TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tournament_id, stage_id, round_number, match_order)
);

CREATE INDEX IF NOT EXISTS idx_bracket_nodes_stage_round
ON bracket_nodes(stage_id, round_number, match_order);

CREATE TABLE IF NOT EXISTS matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID REFERENCES games(id) ON DELETE SET NULL,
  league_id UUID REFERENCES leagues(id) ON DELETE SET NULL,
  series_id UUID REFERENCES series(id) ON DELETE SET NULL,
  tournament_id UUID REFERENCES tournaments(id) ON DELETE SET NULL,
  stage_id UUID REFERENCES tournament_stages(id) ON DELETE SET NULL,
  group_id UUID REFERENCES tournament_groups(id) ON DELETE SET NULL,
  bracket_node_id UUID REFERENCES bracket_nodes(id) ON DELETE SET NULL,
  venue_id UUID REFERENCES venues(id) ON DELETE SET NULL,
  name TEXT,
  slug CITEXT,
  status TEXT NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled', 'pre_match', 'live', 'completed', 'cancelled', 'postponed', 'forfeit', 'unknown')),
  scheduled_at TIMESTAMPTZ,
  begin_at TIMESTAMPTZ,
  end_at TIMESTAMPTZ,
  best_of INT CHECK (best_of IS NULL OR best_of > 0),
  winner_team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
  winner_player_id UUID REFERENCES players(id) ON DELETE SET NULL,
  draw BOOLEAN NOT NULL DEFAULT false,
  importance_score INT NOT NULL DEFAULT 0,
  data_quality_score NUMERIC(4, 3) NOT NULL DEFAULT 0.500
    CHECK (data_quality_score >= 0 AND data_quality_score <= 1),
  last_provider_update_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (slug),
  CHECK (end_at IS NULL OR begin_at IS NULL OR end_at >= begin_at)
);

CREATE TRIGGER matches_set_updated_at
BEFORE UPDATE ON matches
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_matches_today
ON matches(scheduled_at, status);

CREATE INDEX IF NOT EXISTS idx_matches_game_scheduled
ON matches(game_id, scheduled_at DESC);

CREATE INDEX IF NOT EXISTS idx_matches_status_scheduled
ON matches(status, scheduled_at);

CREATE INDEX IF NOT EXISTS idx_matches_tournament_scheduled
ON matches(tournament_id, scheduled_at);

CREATE TABLE IF NOT EXISTS match_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  participant_type TEXT NOT NULL
    CHECK (participant_type IN ('team', 'player', 'placeholder')),
  team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
  player_id UUID REFERENCES players(id) ON DELETE SET NULL,
  side TEXT NOT NULL,
  seed INT,
  score INT NOT NULL DEFAULT 0,
  result TEXT
    CHECK (result IS NULL OR result IN ('win', 'loss', 'draw', 'forfeit', 'unknown')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (
    (participant_type = 'team' AND team_id IS NOT NULL)
    OR (participant_type = 'player' AND player_id IS NOT NULL)
    OR participant_type = 'placeholder'
  ),
  UNIQUE (match_id, side)
);

CREATE TRIGGER match_participants_set_updated_at
BEFORE UPDATE ON match_participants
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_match_participants_team
ON match_participants(team_id, match_id);

CREATE TABLE IF NOT EXISTS match_games (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  game_number INT NOT NULL CHECK (game_number > 0),
  map_name TEXT,
  map_slug CITEXT,
  status TEXT NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled', 'draft', 'live', 'completed', 'cancelled', 'unknown')),
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  winner_team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
  winner_player_id UUID REFERENCES players(id) ON DELETE SET NULL,
  duration_seconds INT CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (match_id, game_number),
  CHECK (ended_at IS NULL OR started_at IS NULL OR ended_at >= started_at)
);

CREATE TRIGGER match_games_set_updated_at
BEFORE UPDATE ON match_games
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_match_games_match
ON match_games(match_id, game_number);

CREATE TABLE IF NOT EXISTS match_game_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_game_id UUID NOT NULL REFERENCES match_games(id) ON DELETE CASCADE,
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  total_rounds INT NOT NULL DEFAULT 0 CHECK (total_rounds >= 0),
  first_half_rounds INT CHECK (first_half_rounds IS NULL OR first_half_rounds >= 0),
  second_half_rounds INT CHECK (second_half_rounds IS NULL OR second_half_rounds >= 0),
  overtime_rounds INT CHECK (overtime_rounds IS NULL OR overtime_rounds >= 0),
  current_side TEXT CHECK (current_side IS NULL OR current_side IN ('CT', 'T')),
  source_provider_id UUID REFERENCES providers(id) ON DELETE SET NULL,
  provider_freshness_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (match_game_id, team_id)
);

CREATE TRIGGER match_game_scores_set_updated_at
BEFORE UPDATE ON match_game_scores
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION enforce_match_game_scores_cs2()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM match_games mg
    JOIN matches m ON m.id = mg.match_id
    JOIN games g ON g.id = m.game_id
    WHERE mg.id = NEW.match_game_id
      AND g.code = 'cs2'
  ) THEN
    RAISE EXCEPTION 'match_game_scores is restricted to CS2 match games';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER match_game_scores_enforce_cs2
BEFORE INSERT OR UPDATE ON match_game_scores
FOR EACH ROW EXECUTE FUNCTION enforce_match_game_scores_cs2();

CREATE INDEX IF NOT EXISTS idx_match_game_scores_game
ON match_game_scores(match_game_id);

CREATE INDEX IF NOT EXISTS idx_match_game_scores_team
ON match_game_scores(team_id);

CREATE TABLE IF NOT EXISTS match_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  participant_id UUID REFERENCES match_participants(id) ON DELETE CASCADE,
  team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
  player_id UUID REFERENCES players(id) ON DELETE SET NULL,
  score_type TEXT NOT NULL DEFAULT 'match'
    CHECK (score_type IN ('match', 'map', 'round', 'series', 'aggregate')),
  game_number INT,
  value NUMERIC(12, 3) NOT NULL DEFAULT 0,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_match_scores_match_recorded
ON match_scores(match_id, recorded_at DESC);

CREATE TABLE IF NOT EXISTS score_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  snapshot_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  score JSONB NOT NULL,
  source_provider_id UUID REFERENCES providers(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_score_snapshots_match_time
ON score_snapshots(match_id, snapshot_at DESC);

CREATE INDEX IF NOT EXISTS idx_score_snapshots_score_gin
ON score_snapshots USING GIN(score);

CREATE TABLE IF NOT EXISTS live_match_states (
  match_id UUID PRIMARY KEY REFERENCES matches(id) ON DELETE CASCADE,
  status TEXT NOT NULL,
  current_game_id UUID REFERENCES match_games(id) ON DELETE SET NULL,
  clock_seconds INT CHECK (clock_seconds IS NULL OR clock_seconds >= 0),
  state JSONB NOT NULL DEFAULT '{}'::jsonb,
  source_provider_id UUID REFERENCES providers(id) ON DELETE SET NULL,
  provider_freshness_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_live_match_states_status
ON live_match_states(status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_live_match_states_state_gin
ON live_match_states USING GIN(state);

CREATE TABLE IF NOT EXISTS live_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  match_game_id UUID REFERENCES match_games(id) ON DELETE CASCADE,
  sequence BIGINT NOT NULL,
  event_type TEXT NOT NULL,
  occurred_at TIMESTAMPTZ,
  actor_team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
  actor_player_id UUID REFERENCES players(id) ON DELETE SET NULL,
  target_team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
  target_player_id UUID REFERENCES players(id) ON DELETE SET NULL,
  source_provider_id UUID REFERENCES providers(id) ON DELETE SET NULL,
  external_event_id TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (match_id, sequence)
);

CREATE INDEX IF NOT EXISTS idx_live_events_match_sequence
ON live_events(match_id, sequence);

CREATE INDEX IF NOT EXISTS idx_live_events_match_time
ON live_events(match_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_live_events_type_time
ON live_events(event_type, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_live_events_payload_gin
ON live_events USING GIN(payload);

CREATE TABLE IF NOT EXISTS match_timeline_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  live_event_id UUID REFERENCES live_events(id) ON DELETE SET NULL,
  title_en TEXT,
  title_ar TEXT,
  body_en TEXT,
  body_ar TEXT,
  icon TEXT,
  event_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  sort_order BIGINT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (match_id, sort_order)
);

CREATE INDEX IF NOT EXISTS idx_match_timeline_match_order
ON match_timeline_events(match_id, sort_order);

CREATE TABLE IF NOT EXISTS stat_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID REFERENCES games(id) ON DELETE CASCADE,
  scope TEXT NOT NULL CHECK (scope IN ('player', 'team', 'match', 'game', 'tournament')),
  code CITEXT NOT NULL,
  display_name_en TEXT NOT NULL,
  display_name_ar TEXT,
  value_type TEXT NOT NULL
    CHECK (value_type IN ('integer', 'decimal', 'percentage', 'duration', 'boolean', 'text')),
  unit TEXT,
  higher_is_better BOOLEAN,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (game_id, scope, code)
);

CREATE TRIGGER stat_definitions_set_updated_at
BEFORE UPDATE ON stat_definitions
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS player_game_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_game_id UUID NOT NULL REFERENCES match_games(id) ON DELETE CASCADE,
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
  stats JSONB NOT NULL DEFAULT '{}'::jsonb,
  source_provider_id UUID REFERENCES providers(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (match_game_id, player_id)
);

CREATE TRIGGER player_game_stats_set_updated_at
BEFORE UPDATE ON player_game_stats
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_player_game_stats_player
ON player_game_stats(player_id, match_id);

CREATE INDEX IF NOT EXISTS idx_player_game_stats_stats_gin
ON player_game_stats USING GIN(stats);

CREATE TABLE IF NOT EXISTS team_game_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_game_id UUID NOT NULL REFERENCES match_games(id) ON DELETE CASCADE,
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  stats JSONB NOT NULL DEFAULT '{}'::jsonb,
  source_provider_id UUID REFERENCES providers(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (match_game_id, team_id)
);

CREATE TRIGGER team_game_stats_set_updated_at
BEFORE UPDATE ON team_game_stats
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_team_game_stats_team
ON team_game_stats(team_id, match_id);

CREATE INDEX IF NOT EXISTS idx_team_game_stats_stats_gin
ON team_game_stats USING GIN(stats);

CREATE TABLE IF NOT EXISTS match_stat_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  snapshot_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  stats JSONB NOT NULL DEFAULT '{}'::jsonb,
  source_provider_id UUID REFERENCES providers(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_match_stat_snapshots_match_time
ON match_stat_snapshots(match_id, snapshot_at DESC);

CREATE TABLE IF NOT EXISTS content_channels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID REFERENCES providers(id) ON DELETE SET NULL,
  channel_type TEXT NOT NULL CHECK (channel_type IN ('twitch', 'youtube', 'x', 'rss', 'website', 'discord', 'other')),
  external_id TEXT,
  handle TEXT,
  display_name TEXT NOT NULL,
  url TEXT,
  is_official BOOLEAN NOT NULL DEFAULT false,
  related_entity_type TEXT,
  related_entity_id UUID,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (channel_type, external_id)
);

CREATE TRIGGER content_channels_set_updated_at
BEFORE UPDATE ON content_channels
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_content_channels_related
ON content_channels(related_entity_type, related_entity_id);

CREATE TABLE IF NOT EXISTS streams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id UUID REFERENCES content_channels(id) ON DELETE SET NULL,
  match_id UUID REFERENCES matches(id) ON DELETE SET NULL,
  tournament_id UUID REFERENCES tournaments(id) ON DELETE SET NULL,
  provider_id UUID REFERENCES providers(id) ON DELETE SET NULL,
  external_id TEXT,
  title TEXT,
  language TEXT,
  url TEXT NOT NULL,
  thumbnail_url TEXT,
  viewer_count INT CHECK (viewer_count IS NULL OR viewer_count >= 0),
  is_live BOOLEAN NOT NULL DEFAULT false,
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  last_checked_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER streams_set_updated_at
BEFORE UPDATE ON streams
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_streams_live
ON streams(is_live, last_checked_at DESC);

CREATE INDEX IF NOT EXISTS idx_streams_match
ON streams(match_id);

CREATE TABLE IF NOT EXISTS videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id UUID REFERENCES content_channels(id) ON DELETE SET NULL,
  match_id UUID REFERENCES matches(id) ON DELETE SET NULL,
  tournament_id UUID REFERENCES tournaments(id) ON DELETE SET NULL,
  provider_id UUID REFERENCES providers(id) ON DELETE SET NULL,
  external_id TEXT,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  thumbnail_url TEXT,
  published_at TIMESTAMPTZ,
  duration_seconds INT CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER videos_set_updated_at
BEFORE UPDATE ON videos
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_videos_match
ON videos(match_id, published_at DESC);

CREATE TABLE IF NOT EXISTS news_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID REFERENCES providers(id) ON DELETE SET NULL,
  source_name TEXT NOT NULL,
  source_url TEXT,
  external_id TEXT,
  title TEXT NOT NULL,
  summary TEXT,
  language TEXT NOT NULL DEFAULT 'ar',
  url TEXT NOT NULL,
  image_url TEXT,
  published_at TIMESTAMPTZ,
  related_entity_type TEXT,
  related_entity_id UUID,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER news_items_set_updated_at
BEFORE UPDATE ON news_items
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_news_published
ON news_items(language, published_at DESC);

CREATE INDEX IF NOT EXISTS idx_news_related
ON news_items(related_entity_type, related_entity_id);

CREATE TABLE IF NOT EXISTS provider_entity_map (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  external_id TEXT NOT NULL,
  external_slug TEXT,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  confidence NUMERIC(4, 3) NOT NULL DEFAULT 1.000
    CHECK (confidence >= 0 AND confidence <= 1),
  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (provider_id, entity_type, external_id)
);

CREATE INDEX IF NOT EXISTS idx_provider_entity_map_internal
ON provider_entity_map(entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_provider_entity_map_slug
ON provider_entity_map(provider_id, entity_type, external_slug);

CREATE INDEX IF NOT EXISTS idx_provider_entity_map_metadata_gin
ON provider_entity_map USING GIN(metadata);

CREATE TABLE IF NOT EXISTS provider_payloads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
  feed_type TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  external_id TEXT,
  endpoint TEXT,
  request_params JSONB NOT NULL DEFAULT '{}'::jsonb,
  payload JSONB NOT NULL,
  payload_hash TEXT NOT NULL,
  provider_schema_version TEXT,
  source_updated_at TIMESTAMPTZ,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  sync_job_id UUID,
  UNIQUE (provider_id, feed_type, external_id, payload_hash)
);

CREATE INDEX IF NOT EXISTS idx_provider_payloads_feed_time
ON provider_payloads(provider_id, feed_type, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_provider_payloads_entity_time
ON provider_payloads(entity_type, entity_id, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_provider_payloads_payload_gin
ON provider_payloads USING GIN(payload jsonb_path_ops);

CREATE TABLE IF NOT EXISTS sync_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID REFERENCES providers(id) ON DELETE SET NULL,
  job_type TEXT NOT NULL,
  feed_type TEXT,
  status TEXT NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'running', 'succeeded', 'failed', 'cancelled')),
  scope JSONB NOT NULL DEFAULT '{}'::jsonb,
  cursor_before TEXT,
  cursor_after TEXT,
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  stats JSONB NOT NULL DEFAULT '{}'::jsonb,
  error JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (finished_at IS NULL OR started_at IS NULL OR finished_at >= started_at)
);

CREATE INDEX IF NOT EXISTS idx_sync_jobs_provider_status
ON sync_jobs(provider_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS sync_cursors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
  feed_type TEXT NOT NULL,
  scope TEXT NOT NULL DEFAULT 'global',
  cursor_value TEXT,
  high_watermark TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (provider_id, feed_type, scope)
);

CREATE TABLE IF NOT EXISTS sync_conflicts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID REFERENCES providers(id) ON DELETE SET NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  external_id TEXT,
  conflict_type TEXT NOT NULL,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'resolved', 'ignored')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_sync_conflicts_status
ON sync_conflicts(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sync_conflicts_entity
ON sync_conflicts(entity_type, entity_id);

CREATE TABLE IF NOT EXISTS app_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_subject TEXT UNIQUE,
  email TEXT UNIQUE,
  hashed_password TEXT,
  display_name TEXT,
  locale TEXT NOT NULL DEFAULT 'ar',
  timezone TEXT NOT NULL DEFAULT 'Asia/Riyadh',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_users_email
ON app_users(lower(email))
WHERE email IS NOT NULL;

CREATE TRIGGER app_users_set_updated_at
BEFORE UPDATE ON app_users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS user_preferences (
  user_id UUID PRIMARY KEY REFERENCES app_users(id) ON DELETE CASCADE,
  language TEXT NOT NULL DEFAULT 'ar' CHECK (language IN ('ar', 'en')),
  calendar_preference TEXT NOT NULL DEFAULT 'gregorian'
    CHECK (calendar_preference IN ('gregorian', 'hijri')),
  saudi_fan_mode BOOLEAN NOT NULL DEFAULT false,
  notifications_enabled BOOLEAN NOT NULL DEFAULT true,
  notif_match_start BOOLEAN NOT NULL DEFAULT true,
  notif_score_change BOOLEAN NOT NULL DEFAULT true,
  notif_match_end BOOLEAN NOT NULL DEFAULT true,
  notif_roster_change BOOLEAN NOT NULL DEFAULT true,
  notif_stream_live BOOLEAN NOT NULL DEFAULT true,
  notif_fantasy_remind BOOLEAN NOT NULL DEFAULT true,
  quiet_hours JSONB NOT NULL DEFAULT '{}'::jsonb,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER user_preferences_set_updated_at
BEFORE UPDATE ON user_preferences
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_user_preferences_saudi
ON user_preferences(saudi_fan_mode)
WHERE saudi_fan_mode = true;

CREATE TABLE IF NOT EXISTS user_follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL
    CHECK (entity_type IN ('game', 'team', 'player', 'league', 'series', 'tournament', 'match')),
  entity_id UUID NOT NULL,
  notification_level TEXT NOT NULL DEFAULT 'normal'
    CHECK (notification_level IN ('off', 'normal', 'important', 'all')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, entity_type, entity_id)
);

CREATE INDEX IF NOT EXISTS idx_user_follows_entity
ON user_follows(entity_type, entity_id);

CREATE TABLE IF NOT EXISTS device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'ipad_os', 'web')),
  token_hash TEXT NOT NULL,
  token_encrypted TEXT NOT NULL,
  environment TEXT NOT NULL DEFAULT 'sandbox'
    CHECK (environment IN ('sandbox', 'production')),
  app_version TEXT,
  locale TEXT,
  timezone TEXT,
  enabled BOOLEAN NOT NULL DEFAULT true,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (platform, token_hash, environment)
);

CREATE TRIGGER device_tokens_set_updated_at
BEFORE UPDATE ON device_tokens
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_enabled
ON device_tokens(user_id, enabled);

CREATE TABLE IF NOT EXISTS notification_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL,
  channel TEXT NOT NULL DEFAULT 'push' CHECK (channel IN ('push', 'in_app', 'email')),
  locale TEXT NOT NULL,
  title_template TEXT NOT NULL,
  body_template TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (code, channel, locale)
);

CREATE TRIGGER notification_templates_set_updated_at
BEFORE UPDATE ON notification_templates
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS notification_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  audience JSONB NOT NULL DEFAULT '{}'::jsonb,
  send_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'sent', 'failed', 'cancelled')),
  attempts INT NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER notification_jobs_set_updated_at
BEFORE UPDATE ON notification_jobs
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_notification_jobs_status_send
ON notification_jobs(status, send_at);

CREATE TABLE IF NOT EXISTS notification_deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES notification_jobs(id) ON DELETE CASCADE,
  user_id UUID REFERENCES app_users(id) ON DELETE SET NULL,
  device_token_id UUID REFERENCES device_tokens(id) ON DELETE SET NULL,
  channel TEXT NOT NULL DEFAULT 'push',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'sent', 'failed', 'dismissed')),
  provider_message_id TEXT,
  error TEXT,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (job_id, device_token_id, channel)
);

CREATE INDEX IF NOT EXISTS idx_notification_deliveries_user
ON notification_deliveries(user_id, status, sent_at DESC);

CREATE TABLE IF NOT EXISTS fantasy_contests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID REFERENCES games(id) ON DELETE SET NULL,
  tournament_id UUID REFERENCES tournaments(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  rules JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'open', 'locked', 'scoring', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (ends_at >= starts_at)
);

CREATE TRIGGER fantasy_contests_set_updated_at
BEFORE UPDATE ON fantasy_contests
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_fantasy_contests_game_time
ON fantasy_contests(game_id, starts_at DESC);

CREATE TABLE IF NOT EXISTS fantasy_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contest_id UUID NOT NULL REFERENCES fantasy_contests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'locked', 'disqualified', 'completed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (contest_id, user_id)
);

CREATE TRIGGER fantasy_entries_set_updated_at
BEFORE UPDATE ON fantasy_entries
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS fantasy_entry_players (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id UUID NOT NULL REFERENCES fantasy_entries(id) ON DELETE CASCADE,
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  slot TEXT NOT NULL,
  multiplier NUMERIC(8, 3) NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (entry_id, slot),
  UNIQUE (entry_id, player_id)
);

CREATE TABLE IF NOT EXISTS fantasy_score_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contest_id UUID NOT NULL REFERENCES fantasy_contests(id) ON DELETE CASCADE,
  player_id UUID REFERENCES players(id) ON DELETE SET NULL,
  match_id UUID REFERENCES matches(id) ON DELETE SET NULL,
  stat_code TEXT NOT NULL,
  points NUMERIC(12, 3) NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fantasy_score_events_contest_player
ON fantasy_score_events(contest_id, player_id);

CREATE TABLE IF NOT EXISTS fantasy_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contest_id UUID NOT NULL REFERENCES fantasy_contests(id) ON DELETE CASCADE,
  entry_id UUID NOT NULL REFERENCES fantasy_entries(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  score NUMERIC(14, 3) NOT NULL DEFAULT 0,
  breakdown JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (contest_id, entry_id)
);

CREATE INDEX IF NOT EXISTS idx_fantasy_scores_leaderboard
ON fantasy_scores(contest_id, score DESC);

CREATE TABLE IF NOT EXISTS ai_models (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL,
  model_name TEXT NOT NULL,
  purpose TEXT NOT NULL,
  version TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (provider, model_name, purpose, version)
);

CREATE TABLE IF NOT EXISTS match_predictions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  model_id UUID REFERENCES ai_models(id) ON DELETE SET NULL,
  output JSONB NOT NULL,
  confidence NUMERIC(4, 3) CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
  input_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_match_predictions_match_time
ON match_predictions(match_id, generated_at DESC);

CREATE TABLE IF NOT EXISTS match_summaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  model_id UUID REFERENCES ai_models(id) ON DELETE SET NULL,
  locale TEXT NOT NULL DEFAULT 'ar',
  summary TEXT NOT NULL,
  highlights JSONB NOT NULL DEFAULT '{}'::jsonb,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (match_id, locale, generated_at)
);

COMMIT;
