# Esports360 Data Strategy

## القرار المختصر

المشكلة ليست في كود iOS فقط. المشكلة أن أغلب مزودي بيانات esports يفصلون بين:

- بيانات مجانية أو منخفضة التكلفة: جداول، نتائج، فرق، بطولات، صور.
- بيانات لحظية حقيقية: WebSocket، play-by-play، frames، إحصائيات دقيقة، وغالباً تكون مدفوعة.

لذلك الحل الدائم ليس الاشتراك في كل API. الحل هو بناء طبقة Backend خاصة بـ Esports360 تكون هي مصدر الحقيقة للتطبيق، وتستخدم APIs خارجية كمصادر تغذية فقط.

## النتيجة النهائية

هذه الخطة هي وجهة Production، وليست كلها مطلوبة دفعة واحدة للـ MVP.

ابدأ بـ:

- PandaScore REST API كمصدر أساسي للمباريات والفرق والبطولات.
- Backend polling + cache لتقديم تجربة شبه مباشرة.
- PostgreSQL كمصدر داخلي موحد.
- Redis للكاش والـ freshness.
- تطبيق iOS يتصل فقط بـ Esports360 API، وليس مباشرة بـ PandaScore.

أجل:

- PandaScore Live WebSocket المدفوع.
- GRID التجاري.
- Riot production API.
- Liquipedia للاستخدام التجاري.

## حدود الـ MVP

الـ MVP لا يحتاج live حقيقي مدفوع. يحتاج تجربة صادقة وسريعة:

- مباريات اليوم والأسبوع.
- نتائج أساسية.
- صور الفرق والبطولات.
- تفاصيل مباراة مقبولة.
- "مباشر تقريبي" بتحديث backend محسوب.
- تنبيهات محلية أو Backend APNs لاحقاً.

أي شيء يتطلب اشتراك Live أو أكثر من API يجب أن يؤجل إلى أن يثبت الاستخدام.

## لماذا WebSocket ليس الحل الآن

PandaScore WebSocket غير متاح في الخطة المجانية. خطط Real-time مخصصة للـ live data وتبدأ بتكلفة عالية لكل لعبة. لذلك الاعتماد عليها من البداية خطر تجارياً.

الحل العملي للـ MVP:

- تحديث المباريات الجارية كل 30-60 ثانية من الـ backend.
- تحديث مباريات اليوم كل 2-5 دقائق.
- تحديث القادم كل 15-30 دقيقة.
- تحديث النتائج النهائية بعد المباراة ثم تثبيتها.
- عرض "آخر تحديث" داخل التطبيق.
- استخدام APNs فقط للأحداث المهمة: بداية مباراة، نهاية، تغيّر نتيجة مهم.

هذا يعطي المستخدم إحساس live بدون دفع تكلفة live كاملة.

## هل نحتاج قاعدة بيانات؟

نعم للإنتاج. لا للعرض التجريبي فقط.

حالياً iOS يملك:

- `MatchRepository` كواجهة جيدة.
- `PandaScoreMatchRepository` كمصدر مباشر.
- `MockMatchRepository` كبديل.
- `SwiftData CachedMatchEntity` موجود لكنه غير مستخدم فعلياً.
- Token محفوظ محلياً للتطوير فقط.

للإنتاج، لا يجب أن يعرف التطبيق مفاتيح PandaScore أو أي مزود آخر.

## قاعدة البيانات المقترحة

PostgreSQL:

- `games`
- `teams`
- `players`
- `tournaments`
- `matches`
- `match_opponents`
- `match_scores`
- `streams`
- `provider_entity_map`
- `user_preferences`
- `provider_fetch_logs`
- `sync_jobs`
- `live_snapshots`
- `notification_jobs`

Redis:

- `matches:today`
- `match:{id}`
- `live:{match_id}`
- `team:{id}`
- `tournament:{id}`
- TTL قصير للمباشر وطويل للأصول والصور.

## جداول حرجة لا يجب تأجيل تصميمها

### `user_preferences`

هذا الجدول يربط المنتج بالمستخدم فعلياً: الفرق المتابعة، الألعاب، اللغة، Saudi Fan Mode، وإعدادات الإشعارات.

```sql
CREATE TABLE user_preferences (
  user_id             UUID PRIMARY KEY,
  followed_teams      INT[] DEFAULT '{}',
  followed_games      INT[] DEFAULT '{}',
  language            VARCHAR(5) DEFAULT 'ar',
  saudi_mode          BOOLEAN DEFAULT false,
  notif_match_start   BOOLEAN DEFAULT true,
  notif_score_change  BOOLEAN DEFAULT true,
  notif_match_end     BOOLEAN DEFAULT true,
  apns_token          TEXT,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);
```

### `provider_entity_map`

نفس الفريق أو اللاعب قد يظهر بمعرف مختلف في PandaScore أو GRID أو أي مزود لاحق. هذا الجدول هو مفتاح عدم ربط قاعدة البيانات بمزود واحد.

```sql
CREATE TABLE provider_entity_map (
  internal_entity_type VARCHAR(50) NOT NULL,
  internal_entity_id   INT NOT NULL,
  provider_name        VARCHAR(50) NOT NULL,
  external_id          VARCHAR(100) NOT NULL,
  confidence           NUMERIC(4, 3) DEFAULT 1.0,
  created_at           TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (internal_entity_type, internal_entity_id, provider_name)
);
```

مثال:

```text
Team Falcons -> pandascore: 1234
Team Falcons -> grid: abc-xyz
```

### `notification_jobs`

إذا أرسل Backend إشعارات APNs، نحتاج queue واضحة قابلة لإعادة المحاولة والتتبع.

```sql
CREATE TABLE notification_jobs (
  id          BIGSERIAL PRIMARY KEY,
  user_ids    UUID[] NOT NULL,
  type        VARCHAR(50) NOT NULL,
  payload     JSONB NOT NULL,
  send_at     TIMESTAMPTZ NOT NULL,
  sent_at     TIMESTAMPTZ,
  status      VARCHAR(20) DEFAULT 'pending',
  attempts    INT DEFAULT 0,
  last_error  TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);
```

## معمارية Production الكاملة

```text
┌─────────────────────────────────────────────────────────────┐
│                     iOS App (Esports360)                    │
│                   يتصل فقط بـ /api/v1/*                    │
└───────────────────────────┬─────────────────────────────────┘
                            │ HTTPS + JWT لاحقاً
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Esports360 Backend (FastAPI / Python)          │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  API Layer   │  │  Scheduler   │  │  Notif Worker    │  │
│  │  /matches    │  │  APScheduler │  │  APNs sender     │  │
│  │  /teams      │  │              │  │                  │  │
│  │  /tournaments│  └──────┬───────┘  └────────┬─────────┘  │
│  └──────┬───────┘         │                   │            │
│         │                 ▼                   ▼            │
│  ┌──────▼─────────────────────────────────────────────┐    │
│  │              Providers Layer                       │    │
│  │  PandaScoreProvider │ TwitchProvider │ YouTubeProvider │
│  │  RiotStaticProvider │ GridProvider لاحقاً             │
│  └──────────────────────────┬──────────────────────────┘    │
└─────────────────────────────┼───────────────────────────────┘
                              │
          ┌───────────────────┼────────────────────┐
          ▼                   ▼                    ▼
   ┌─────────────┐    ┌──────────────┐    ┌──────────────┐
   │ PostgreSQL  │    │    Redis     │    │  APNs/Apple  │
   │ الحقيقة     │    │   Cache      │    │  إشعارات     │
   └─────────────┘    └──────────────┘    └──────────────┘
```

## مشكلة تعدد APIs

لا نربط iOS بكل API. نربط الـ backend بالمزودين.

داخل الـ backend:

- `PandaScoreProvider`
- `RiotStaticProvider`
- `TwitchProvider`
- `YouTubeProvider`
- `GridProvider` لاحقاً

وخارجياً:

- iOS يطلب `/matches/today`
- iOS يطلب `/matches/{id}`
- iOS يطلب `/teams/{id}`
- iOS يطلب `/live/matches/{id}`

بهذا نستطيع تغيير أو إضافة مزود بدون كسر التطبيق.

## خريطة APIs

| المصدر | القرار | الاستخدام |
|---|---|---|
| PandaScore REST | الآن | مباريات، فرق، بطولات، صور، نتائج أساسية |
| PandaScore Live | لاحقاً | WebSocket حقيقي للعبة أو لعبتين عند إثبات الطلب |
| Riot Data Dragon | الآن | أصول LoL الثابتة: أبطال، أيقونات، عناصر |
| Valorant public assets | الآن | Agents/maps/assets |
| Twitch Helix | لاحقاً خفيف | فحص بث القنوات الرسمية فقط |
| YouTube Data API | لاحقاً خفيف | قنوات وبثوث رسمية محددة |
| GRID Open Access | قدّم عليه مبكراً | CS2/Dota 2، لكن لا تجعله أساس MVP |
| Riot API | لاحقاً | إحصائيات أفراد وحسابات، ليس جدول esports رئيسي |
| Liquipedia | لاحقاً فقط بترخيص | تاريخ وأسماء/Aliases، لا كمصدر إنتاج مباشر |

## خطة التنفيذ على سيرفر Docker

السيرفر المتاح: `192.168.0.193`

لا نحتاجه داخل iOS الآن، لكن هو المكان الصحيح للمرحلة التالية.

خدمات Docker المقترحة:

- `api`: FastAPI أو Node/NestJS.
- `worker`: مهام polling من PandaScore.
- `postgres`: قاعدة البيانات.
- `redis`: كاش وحالة live-ish.
- `scheduler`: جدولة refresh.

## تسلسل التنفيذ الصحيح

### المرحلة A — iOS وحده

الحالة الحالية.

- PandaScore مباشرة من iOS مؤقتاً.
- MockRepository للتطوير.
- UI كامل قبل أي Backend.
- رسالة "التحديث اللحظي غير متاح لهذه الخطة" بدل "فشل".

### المرحلة B — Backend أساسي

المدة المتوقعة: 2-3 أسابيع.

- FastAPI + PostgreSQL + Redis.
- `PandaScoreProvider`.
- Worker يجلب المباريات كل 60 ثانية للمباشر.
- `GET /v1/matches/today`.
- `GET /v1/matches/{id}`.
- iOS يتحول من PandaScore مباشرة إلى Backend.
- إزالة PandaScore token من التطبيق.

### المرحلة C — Notifications

المدة المتوقعة: أسبوع.

- APNs من الـ backend.
- `notification_jobs`.
- `user_preferences`.
- إشعار `match_start` قبل 15 دقيقة.
- إشعار `match_end`.
- `score_change` لاحقاً إذا كانت البيانات كافية.

### المرحلة D — Saudi Hub + Streaming

المدة المتوقعة: أسبوع.

- إدخال الفرق السعودية في DB.
- `saudi_mode` من `user_preferences`.
- TwitchProvider للقنوات الرسمية فقط.
- YouTubeProvider للقنوات الرسمية فقط.
- لا polling كثيف ولا search عشوائي.

### المرحلة E — Scale

بعد 1000 مستخدم أو عند ظهور ضغط حقيقي.

- Redis TTL tuning.
- queue للـ polling حسب أولويات المستخدمين.
- GRID Open Access.
- PandaScore Live أو GRID commercial للعبة واحدة فقط إذا ثبتت الحاجة.

## مراحل Backend التفصيلية

1. Endpoint: `GET /v1/matches/today`
2. Worker يجلب PandaScore كل 2-5 دقائق.
3. حفظ normalized matches في PostgreSQL.
4. iOS يتحول من PandaScore مباشرة إلى Esports360 backend.
5. إخفاء PandaScore token بالكامل من التطبيق.

ثم:

- `GET /v1/teams/{id}`
- `GET /v1/tournaments/{id}`
- `GET /v1/live/matches/{id}` يرجع snapshot شبه مباشر.
- SSE أو WebSocket من backend للتطبيق عندما نحتاج push داخل التطبيق.
- APNs للأحداث المهمة خارج التطبيق.

## سياسة التحديث المقترحة

| حالة المباراة | معدل التحديث |
|---|---|
| قبل أكثر من 24 ساعة | كل 6-12 ساعة |
| خلال 24 ساعة | كل 15-30 دقيقة |
| خلال ساعة من البداية | كل 2-5 دقائق |
| مباشرة الآن | كل 30-60 ثانية |
| انتهت للتو | كل دقيقة لمدة 10 دقائق |
| انتهت واستقرت | مرة يومياً أو لا شيء |

## ما يظهر للمستخدم

بدلاً من "فشل":

- "النتائج محدثة"
- "آخر تحديث منذ ٤٢ ثانية"
- "التحديث اللحظي غير متاح لهذه الخطة"
- "مباشر تقريبي"

هذا صادق، ويمنع المستخدم من فهم أن التطبيق معطل.

## القرار التجاري

لا تشترك الآن في كل APIs.

ادفع فقط عندما يثبت أحد هذه الأشياء:

- المستخدمون يفتحون تفاصيل المباريات live بكثافة.
- retention يزيد عند وجود live حقيقي.
- لعبة واحدة تقود أغلب الاستخدام.
- الفانتازي يحتاج إحصائيات دقيقة لا توفرها الخطة المجانية.

عندها نشتري live للعبة واحدة فقط، وليس لكل الألعاب.

## المصادر

- PandaScore Pricing: https://www.pandascore.co/pricing
- PandaScore WebSockets: https://developers.pandascore.co/docs/websockets-overview
- PandaScore Rate Limits: https://developers.pandascore.co/docs/rate-and-connections-limits
- PandaScore Authentication: https://developers.pandascore.co/docs/authentication
- GRID Open Access: https://grid.gg/open-access/
- GRID Quick Start: https://grid.helpjuice.com/client-help/open-access-quickstart
- Riot Developer Portal: https://developer.riotgames.com/docs/portal
- Riot LoL Docs: https://developer.riotgames.com/docs/lol
- Riot VALORANT Docs: https://developer.riotgames.com/docs/valorant
- Twitch API Guide: https://dev.twitch.tv/docs/api/guide/
- YouTube Data API Quota: https://developers.google.com/youtube/v3/getting-started
- Liquipedia API: https://liquipedia.net/api
