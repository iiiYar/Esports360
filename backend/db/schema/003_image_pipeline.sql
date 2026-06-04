-- Esports360 Image Pipeline
-- Stores processed image variants for teams, players, games, maps, tournaments, and leagues.

BEGIN;

CREATE TABLE IF NOT EXISTS media_asset_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  media_asset_id UUID NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
  variant TEXT NOT NULL CHECK (variant IN ('xs', 'sm', 'md', 'lg', 'xl', 'original')),
  format TEXT NOT NULL CHECK (format IN ('png', 'jpg', 'jpeg', 'webp', 'svg')),
  url TEXT NOT NULL,
  storage_key TEXT NOT NULL,
  width INT CHECK (width IS NULL OR width > 0),
  height INT CHECK (height IS NULL OR height > 0),
  byte_size INT CHECK (byte_size IS NULL OR byte_size >= 0),
  checksum TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (media_asset_id, variant, format)
);

CREATE TRIGGER media_asset_variants_set_updated_at
BEFORE UPDATE ON media_asset_variants
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_media_asset_variants_asset
ON media_asset_variants(media_asset_id, variant);

CREATE INDEX IF NOT EXISTS idx_media_asset_variants_storage_key
ON media_asset_variants(storage_key);

CREATE TABLE IF NOT EXISTS game_maps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug CITEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'unknown')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (game_id, slug)
);

CREATE TRIGGER game_maps_set_updated_at
BEFORE UPDATE ON game_maps
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_game_maps_game
ON game_maps(game_id, name);

CREATE TABLE IF NOT EXISTS image_ingestion_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  role TEXT NOT NULL,
  source_url TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('succeeded', 'failed', 'skipped')),
  variants_created INT NOT NULL DEFAULT 0,
  error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_image_ingestion_logs_entity
ON image_ingestion_logs(entity_type, entity_id, created_at DESC);

COMMIT;
