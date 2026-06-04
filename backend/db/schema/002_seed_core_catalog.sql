-- Esports360 initial catalog seed data.

BEGIN;

INSERT INTO providers (code, name, website_url, capabilities, commercial_notes)
VALUES
  ('pandascore', 'PandaScore', 'https://www.pandascore.co', '{"fixtures":true,"results":true,"teams":true,"players":true,"images":true,"live_paid":true}'::jsonb, 'Primary MVP source for fixtures, teams, tournaments, images, and basic results.'),
  ('grid', 'GRID Esports', 'https://grid.gg', '{"official_data":true,"telemetry":true,"open_access":true}'::jsonb, 'Apply early; use later for official telemetry when access is approved.'),
  ('riot', 'Riot Games API', 'https://developer.riotgames.com', '{"lol":true,"valorant":true,"data_dragon":true,"accounts":true}'::jsonb, 'Useful for game-specific data and official assets, not a complete esports feed.'),
  ('abios', 'Abios', 'https://abiosgaming.com', '{"fixtures":true,"stats":true,"live":true,"odds":true}'::jsonb, 'Commercial fallback/expansion provider.'),
  ('liquipedia', 'Liquipedia', 'https://liquipedia.net/api', '{"historical":true,"wiki":true,"transfers":true}'::jsonb, 'Use only with license and usage guideline review.'),
  ('twitch', 'Twitch Helix', 'https://dev.twitch.tv/docs/api', '{"streams":true,"channels":true}'::jsonb, 'Streaming discovery and live status.'),
  ('youtube', 'YouTube Data API', 'https://developers.google.com/youtube/v3/docs', '{"streams":true,"videos":true,"channels":true}'::jsonb, 'Official channel live video detection.'),
  ('opendota', 'OpenDota', 'https://docs.opendota.com', '{"dota2":true,"matches":true,"players":true}'::jsonb, 'Optional Dota 2 enrichment source.'),
  ('faceit', 'FACEIT Data API', 'https://docs.faceit.com/docs/data-api', '{"competitions":true,"matches":true,"teams":true}'::jsonb, 'Optional CS2/community competition source.')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  website_url = EXCLUDED.website_url,
  capabilities = EXCLUDED.capabilities,
  commercial_notes = EXCLUDED.commercial_notes,
  updated_at = now();

INSERT INTO regions (code, name_en, name_ar)
VALUES
  ('global', 'Global', 'عالمي'),
  ('mena', 'MENA', 'الشرق الأوسط وشمال أفريقيا'),
  ('ksa', 'Saudi Arabia', 'السعودية'),
  ('uae', 'United Arab Emirates', 'الإمارات'),
  ('egypt', 'Egypt', 'مصر'),
  ('eu', 'Europe', 'أوروبا'),
  ('na', 'North America', 'أمريكا الشمالية'),
  ('latam', 'Latin America', 'أمريكا اللاتينية'),
  ('apac', 'Asia Pacific', 'آسيا والمحيط الهادئ'),
  ('kr', 'Korea', 'كوريا'),
  ('cn', 'China', 'الصين')
ON CONFLICT (code) DO UPDATE
SET
  name_en = EXCLUDED.name_en,
  name_ar = EXCLUDED.name_ar,
  updated_at = now();

INSERT INTO games (code, name, short_name, genre, publisher, metadata)
VALUES
  ('lol', 'League of Legends', 'LoL', 'MOBA', 'Riot Games', '{"priority":1}'::jsonb),
  ('valorant', 'Valorant', 'VAL', 'Tactical FPS', 'Riot Games', '{"priority":2}'::jsonb),
  ('cs2', 'Counter-Strike 2', 'CS2', 'Tactical FPS', 'Valve', '{"priority":3}'::jsonb),
  ('dota2', 'Dota 2', 'Dota 2', 'MOBA', 'Valve', '{"priority":4}'::jsonb),
  ('rocket-league', 'Rocket League', 'RL', 'Sports', 'Psyonix', '{"priority":5}'::jsonb),
  ('overwatch-2', 'Overwatch 2', 'OW2', 'Hero Shooter', 'Blizzard Entertainment', '{"priority":6}'::jsonb),
  ('rainbow-six-siege', 'Rainbow Six Siege', 'R6', 'Tactical FPS', 'Ubisoft', '{"priority":7}'::jsonb),
  ('pubg', 'PUBG: Battlegrounds', 'PUBG', 'Battle Royale', 'Krafton', '{"priority":8}'::jsonb),
  ('mobile-legends', 'Mobile Legends: Bang Bang', 'MLBB', 'MOBA', 'Moonton', '{"priority":9}'::jsonb),
  ('wild-rift', 'League of Legends: Wild Rift', 'WR', 'MOBA', 'Riot Games', '{"priority":10}'::jsonb),
  ('ea-fc', 'EA Sports FC', 'EA FC', 'Sports', 'Electronic Arts', '{"priority":11}'::jsonb),
  ('starcraft-2', 'StarCraft II', 'SC2', 'RTS', 'Blizzard Entertainment', '{"priority":12}'::jsonb)
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  short_name = EXCLUDED.short_name,
  genre = EXCLUDED.genre,
  publisher = EXCLUDED.publisher,
  metadata = EXCLUDED.metadata,
  updated_at = now();

INSERT INTO stat_definitions (game_id, scope, code, display_name_en, display_name_ar, value_type, unit, higher_is_better)
SELECT g.id, s.scope, s.code, s.display_name_en, s.display_name_ar, s.value_type, s.unit, s.higher_is_better
FROM games g
JOIN (
  VALUES
    ('lol', 'player', 'kills', 'Kills', 'القتلات', 'integer', NULL, true),
    ('lol', 'player', 'deaths', 'Deaths', 'الموتات', 'integer', NULL, false),
    ('lol', 'player', 'assists', 'Assists', 'المساعدات', 'integer', NULL, true),
    ('lol', 'player', 'gold', 'Gold', 'الذهب', 'integer', NULL, true),
    ('valorant', 'player', 'kills', 'Kills', 'القتلات', 'integer', NULL, true),
    ('valorant', 'player', 'deaths', 'Deaths', 'الموتات', 'integer', NULL, false),
    ('valorant', 'player', 'assists', 'Assists', 'المساعدات', 'integer', NULL, true),
    ('valorant', 'player', 'acs', 'Average Combat Score', 'متوسط نقاط القتال', 'decimal', NULL, true),
    ('cs2', 'player', 'kills', 'Kills', 'القتلات', 'integer', NULL, true),
    ('cs2', 'player', 'deaths', 'Deaths', 'الموتات', 'integer', NULL, false),
    ('cs2', 'player', 'adr', 'Average Damage per Round', 'متوسط الضرر لكل جولة', 'decimal', NULL, true),
    ('dota2', 'player', 'kills', 'Kills', 'القتلات', 'integer', NULL, true),
    ('dota2', 'player', 'deaths', 'Deaths', 'الموتات', 'integer', NULL, false),
    ('dota2', 'player', 'assists', 'Assists', 'المساعدات', 'integer', NULL, true),
    ('dota2', 'player', 'gpm', 'Gold per Minute', 'الذهب لكل دقيقة', 'decimal', NULL, true)
) AS s(game_code, scope, code, display_name_en, display_name_ar, value_type, unit, higher_is_better)
ON g.code = s.game_code
ON CONFLICT (game_id, scope, code) DO UPDATE
SET
  display_name_en = EXCLUDED.display_name_en,
  display_name_ar = EXCLUDED.display_name_ar,
  value_type = EXCLUDED.value_type,
  unit = EXCLUDED.unit,
  higher_is_better = EXCLUDED.higher_is_better,
  updated_at = now();

COMMIT;
