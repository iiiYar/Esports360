-- Esports360 game logo sources.
-- Keeps game media sources in DB metadata so the media pipeline can replace
-- generated placeholders with provider/official CDN assets.

BEGIN;

WITH sources(code, logo_url, logo_source, logo_source_page) AS (
  VALUES
    ('lol', 'https://cdn.jsdelivr.net/npm/simple-icons@15/icons/leagueoflegends.svg', 'simple-icons', 'https://simpleicons.org/?q=League%20of%20Legends'),
    ('valorant', 'https://cdn.jsdelivr.net/npm/simple-icons@15/icons/valorant.svg', 'simple-icons', 'https://simpleicons.org/?q=Valorant'),
    ('cs2', 'https://cdn.jsdelivr.net/npm/simple-icons@15/icons/counterstrike.svg', 'simple-icons', 'https://simpleicons.org/?q=Counter-Strike'),
    ('dota2', 'https://cdn.jsdelivr.net/npm/simple-icons@15/icons/dota2.svg', 'simple-icons', 'https://simpleicons.org/?q=Dota%202'),
    ('pubg', 'https://cdn.jsdelivr.net/npm/simple-icons@15/icons/pubg.svg', 'simple-icons', 'https://simpleicons.org/?q=PUBG'),
    ('ea-fc', 'https://cdn.jsdelivr.net/npm/simple-icons@15/icons/ea.svg', 'simple-icons', 'https://simpleicons.org/?q=EA'),
    ('fifa', 'https://cdn.jsdelivr.net/npm/simple-icons@15/icons/fifa.svg', 'simple-icons', 'https://simpleicons.org/?q=FIFA'),
    ('wild-rift', 'https://commons.wikimedia.org/wiki/Special:Redirect/file/League_of_Legends_Wild_Rift_logo.svg', 'wikimedia-riot-asset', 'https://commons.wikimedia.org/wiki/File:League_of_Legends_Wild_Rift_logo.svg'),
    ('mobile-legends', 'https://dl.svgcdn.com/png/arcticons/mobile-legends-bang-bang-800.png', 'arcticons', 'https://superdevpro.com/brands/mobile-legends-bang-bang'),
    ('mlbb', 'https://dl.svgcdn.com/png/arcticons/mobile-legends-bang-bang-800.png', 'arcticons', 'https://superdevpro.com/brands/mobile-legends-bang-bang'),
    ('rocket-league', 'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/252950/header.jpg', 'steam-store-assets', 'https://store.steampowered.com/app/252950/Rocket_League/'),
    ('rl', 'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/252950/header.jpg', 'steam-store-assets', 'https://store.steampowered.com/app/252950/Rocket_League/'),
    ('overwatch-2', 'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2357570/header.jpg', 'steam-store-assets', 'https://store.steampowered.com/app/2357570/Overwatch_2/'),
    ('ow', 'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2357570/header.jpg', 'steam-store-assets', 'https://store.steampowered.com/app/2357570/Overwatch_2/'),
    ('rainbow-six-siege', 'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/359550/header.jpg', 'steam-store-assets', 'https://store.steampowered.com/app/359550/Tom_Clancys_Rainbow_Six_Siege/'),
    ('r6-siege', 'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/359550/header.jpg', 'steam-store-assets', 'https://store.steampowered.com/app/359550/Tom_Clancys_Rainbow_Six_Siege/'),
    ('cod-mw', 'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2000950/header.jpg', 'steam-store-assets', 'https://store.steampowered.com/app/2000950/Call_of_Duty_Modern_Warfare/'),
    ('starcraft-2', 'https://commons.wikimedia.org/wiki/Special:Redirect/file/StarCraft_Logo.png', 'wikimedia-blizzard-asset', 'https://commons.wikimedia.org/wiki/File:StarCraft_Logo.png'),
    ('starcraft-brood-war', 'https://commons.wikimedia.org/wiki/Special:Redirect/file/StarCraft_Logo.png', 'wikimedia-blizzard-asset', 'https://commons.wikimedia.org/wiki/File:StarCraft_Logo.png')
)
UPDATE games g
SET metadata =
  g.metadata || jsonb_build_object(
    'media',
    coalesce(g.metadata -> 'media', '{}'::jsonb) || jsonb_build_object(
      'logo_url', s.logo_url,
      'logo_source', s.logo_source,
      'logo_source_page', s.logo_source_page
    )
  ),
  updated_at = now()
FROM sources s
WHERE g.code = s.code;

COMMIT;
