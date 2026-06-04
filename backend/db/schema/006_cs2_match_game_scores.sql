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

DROP TRIGGER IF EXISTS match_game_scores_set_updated_at ON match_game_scores;
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

DROP TRIGGER IF EXISTS match_game_scores_enforce_cs2 ON match_game_scores;
CREATE TRIGGER match_game_scores_enforce_cs2
BEFORE INSERT OR UPDATE ON match_game_scores
FOR EACH ROW EXECUTE FUNCTION enforce_match_game_scores_cs2();

CREATE INDEX IF NOT EXISTS idx_match_game_scores_game
ON match_game_scores(match_game_id);

CREATE INDEX IF NOT EXISTS idx_match_game_scores_team
ON match_game_scores(team_id);
