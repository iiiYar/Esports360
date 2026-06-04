# 🗂️ قائمة مهام جلب تفاصيل الجولات والجانب النشط لـ CS2 (CS2 Live Round Scores Ingestion)

## المرحلة 1 — تحديث الإعدادات وFeature Flags ⚙️
- `[x]` إضافة حقل `cs2_hltv_detail_enabled` في [shared/config.py](file:///Users/iyar/Documents/Codex/2026-05-23/ios/backend/services/shared/esports360/config.py) ✅
- `[x]` إضافة حقل `cs2_hltv_detail_enabled` في [cs2-collector/config.py](file:///Users/iyar/Documents/Codex/2026-05-23/ios/backend/services/cs2-collector/esports360/config.py) ✅


## المرحلة 2 — تطوير كاشط تفاصيل الجولات المتقدم 🧠
- `[x]` تحديث دالة `_parse_el` في [hltv_engine.py](file:///Users/iyar/Documents/Codex/2026-05-23/ios/backend/services/cs2-collector/engines/hltv_engine.py) لتخزين `detail_url` لكل خريطة. ✅
- `[x]` كتابة دالة `_fetch_url` غير المحظورة لصفحات تفاصيل المباريات. ✅
- `[x]` تحديث `_poll_page` لتعمل بـ `asyncio.Semaphore(2)` لجلب تفاصيل الحد الأقصى (2-3) من المباريات الحية بشكل متزامن وآمن. ✅
- `[x]` إضافة الدالة العبقرية `_sync_detail_page_scores` وتفكيك محتوى الأنصاف والجانب النشط. ✅
- `[x]` تفعيل حماية تداخل المصادر (Authority Protection) بحيث لا يتم الكتابة فوق بيانات PandaScore/GRID المستقبلية في جدول `match_game_scores`. ✅
- `[x]` إضافة سجلات (Logs) واضحة وتغيير أي صياغات حساسة إلى "HLTV detail fetcher / optional enrichment". ✅


## المرحلة 3 — كتابة سكربت الأتمتة والنشر للسيرفر 🚀
- `[x]` كتابة سكربت رفع ونشر الكود وتحديث البناء على السيرفر `192.168.0.193` ✅
- `[x]` تنفيذ عملية الرفع والمزامنة وإعادة تشغيل حاوية `cs2-collector` ✅
- `[x]` اختبار وقراءة سجلات الحاوية على السيرفر البعيد والتأكد من نجاح جلب وحقن جولات المباريات والجانب CT/T بنجاح تام! ✅

