# Esports360 API Data Model Study

## الهدف

هذه الوثيقة تحول مصادر بيانات الرياضات الإلكترونية إلى نموذج داخلي واحد لـ Esports360.
القاعدة الذهبية: لا يكون تطبيق iOS مربوطاً بأي مزود خارجي. كل شيء يمر عبر Backend و PostgreSQL.

## الخلاصة التنفيذية

لا يوجد API واحد يعطي كل شيء بسعر مناسب منذ اليوم الأول.
لذلك نبني قاعدة بيانات provider-neutral:

- `PandaScore` للمباريات، الفرق، اللاعبين، البطولات، الصور، والنتائج الأساسية.
- `GRID / Riot Esports Data` لاحقاً للـ telemetry والبيانات الرسمية الحية عندما نحتاج مستوى احترافي.
- `Riot APIs` للأصول والحسابات وبيانات LoL/Valorant غير المصممة لتكون feed شامل للبطولات.
- `Abios` كبديل تجاري واسع عند الحاجة لتغطية إضافية.
- `Liquipedia` كمصدر تاريخي/مرجعي بحذر ترخيصي، وليس كمصدر إنتاج مباشر بدون موافقة.
- `Twitch` و `YouTube` للبث، وليس لنتائج المباريات.
- `OpenDota` و `FACEIT` يمكن إضافتهما لاحقاً كمصادر لعبة محددة.

## نمط البيانات حسب المزود

| المزود | نمط البيانات | المعرفات | قوة المصدر | قرار Esports360 |
|---|---|---|---|---|
| PandaScore | Videogames, leagues, series, tournaments, teams, players, matches, games/maps, streams, images | IDs رقمية و slugs | ممتاز للـ MVP والجداول والنتائج | المصدر الأساسي الآن |
| PandaScore Live | WebSocket/Live frames/events حسب الخطة | IDs PandaScore | قوي لكنه مدفوع | يؤجل حتى تثبت الحاجة |
| GRID Open Access | بيانات رسمية/telemetry لبعض الألعاب، خصوصاً CS2/Dota 2 في Open Access | IDs خاصة بـ GRID | رسمي وقوي | نقدم عليه مبكراً، لا نجعله شرط MVP |
| Riot APIs | Match history, accounts, Data Dragon, Valorant content/matches | PUUID, match IDs, content IDs | رسمي لكنه ليس feed شامل للـ esports | أصول وإحصائيات لعبة محددة |
| Abios | Fixtures, series, matches, rosters, stats, live/odds حسب المنتج | IDs غالباً رقمية | تجاري واسع | Fallback/مرحلة توسع |
| Liquipedia | فرق، لاعبين، بطولات، انتقالات، تاريخ، standings | Page titles/MediaWiki/LPDB IDs | واسع تاريخياً | مرجعي فقط مع احترام الترخيص |
| Twitch Helix | Streams, channels, viewer counts, live status | User IDs, game IDs, stream IDs | رسمي للبث | Saudi Hub وصفحات البطولات |
| YouTube Data API | Live search/videos/channels | Channel/video IDs | رسمي للبث | بثوث رسمية محددة |
| OpenDota | Dota matches, players, teams, pro matches | Steam/account/match IDs | جيد لـ Dota | لاحقاً فقط للعبة محددة |
| FACEIT Data API | Competitions, matches, teams, players | FACEIT GUIDs | جيد لـ CS2 community/pro circuits | لاحقاً حسب الحاجة |

## النموذج الداخلي الموحد

كل مزود يختلف في التسميات. النموذج الداخلي يجب أن يكون ثابتاً:

```text
Game
  League
    Series / Season
      Tournament
        Stage
          Group / Bracket Round
            Match
              Match Participant
              Match Game / Map
                Live Event
                Player Stats
                Team Stats
```

## فصل البيانات الخام عن بيانات المنتج

نحفظ نوعين من البيانات:

- بيانات داخلية منظمة: `teams`, `players`, `matches`, `tournaments`.
- بيانات خام كما وصلت من المزود: `raw_provider_payloads`.

هذا يسمح لنا بالآتي:

- إعادة بناء normalized data عند تغيير mapper.
- مقارنة اختلاف المزودين.
- إصلاح أخطاء الربط بين Team Falcons مثلاً في أكثر من مصدر.
- إضافة مزود جديد بدون كسر iOS.

## جداول الربط بين المزودين

كل كيان داخلي له UUID ثابت.
كل معرف خارجي يحفظ في:

- `provider_entity_map`
- `provider_payloads`
- `sync_cursors`
- `sync_jobs`
- `sync_conflicts`

مثال:

```text
teams.id = 4b... internal UUID
PandaScore external_id = 1234
GRID external_id = abc-xyz
Liquipedia external_slug = Team_Falcons
```

## لماذا UUID داخلي؟

لأن مزودي esports لا يملكون معياراً عالمياً موحداً.
استخدام UUID داخلي يمنع تسرب معرف PandaScore إلى iOS أو الإشعارات أو fantasy أو AI.

## الإحصائيات

إحصائيات الرياضات الإلكترونية تختلف جذرياً:

- LoL: champions, gold, towers, dragons, bans, picks.
- Valorant: agents, maps, rounds, K/D/A, plants, defuses.
- CS2: maps, rounds, ADR, HS%, clutches.
- Dota 2: heroes, net worth, GPM/XPM, Roshan, items.

لذلك المرحلة الأولى تستخدم:

- `stat_definitions` لتعريف معنى كل stat.
- `player_game_stats.stats JSONB`.
- `team_game_stats.stats JSONB`.
- `match_stat_snapshots.stats JSONB`.

وعند ظهور leaderboard مهم، نضيف جدول مشتق سريع بدون كسر التخزين الخام.

## المباريات الحية

بسبب تكلفة WebSocket الحقيقية، قاعدة البيانات تدعم live من الآن لكن لا تشترطه:

- `live_match_states` لحالة المباراة الحالية.
- `live_events` للأحداث المتتابعة.
- `match_timeline_events` للعرض داخل iOS.
- `score_snapshots` لمقارنة تغير النتيجة وإرسال إشعارات.

في MVP يمكن للـ worker تحديثها كل 30-60 ثانية من REST.
لاحقاً يمكن إدخال WebSocket من PandaScore أو GRID في نفس الجداول.

## المستخدمون والإشعارات

نستخدم جداول follow طبيعية بدلاً من arrays:

- `user_follows`
- `user_preferences`
- `device_tokens`
- `notification_jobs`
- `notification_deliveries`

هذا أفضل للفهرسة ومعرفة "من يتابع هذا الفريق؟" عند حدوث مباراة.

## مصادر رسمية

- PandaScore Developers: https://developers.pandascore.co/docs/introduction
- PandaScore WebSockets: https://developers.pandascore.co/docs/websockets-overview
- PandaScore Pricing: https://www.pandascore.co/pricing
- GRID Open Access: https://grid.gg/open-access/
- Riot Esports Data: https://riotesportsdata.com/
- Riot Developer Portal: https://developer.riotgames.com/apis
- Riot LoL Docs: https://developer.riotgames.com/docs/lol
- Riot Valorant Docs: https://developer.riotgames.com/docs/valorant
- Twitch API: https://dev.twitch.tv/docs/api/
- YouTube Data API: https://developers.google.com/youtube/v3/docs
- Abios Esports API: https://abiosgaming.com/esports-data-api
- Liquipedia API: https://liquipedia.net/api
- Liquipedia API Terms: https://liquipedia.net/api-terms-of-use
- OpenDota API: https://docs.opendota.com/
- FACEIT Data API: https://docs.faceit.com/docs/data-api/

## قرار المرحلة الأولى

سننشئ schema واسعة من أول يوم، لكن نستخدم جزءاً صغيراً في API:

- مباريات اليوم.
- تفاصيل مباراة.
- فرق ولاعبين.
- بطولات.
- live-ish state.
- user follows.
- notification jobs.

بهذا نحصل على أساس Production بدون إجبار MVP على الاشتراك في كل API.
