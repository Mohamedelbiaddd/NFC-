# NFC Studio

تطبيق Flutter لإدارة بطاقات NFC متعددة المستأجرين مع Supabase، وواجهة ويب عامة
للروابط المخصصة `/p/<slug>` منشورة من مجلد `web_profiles`.

## المكوّنات

- `lib/screens/dashboard.dart` — لوحة التحكم: الأنشطة التجارية، ملفات NFC، الفريق.
- `lib/screens/profile_editor.dart` — تحرير الملف: البيانات، الرابط المخصص، **صورة
  الملف** (اختيار من المعرض ورفعها إلى Supabase Storage وتخزين الرابط في
  `nfc_profiles.image_url`).
- `lib/screens/qr_screen.dart` — **رمز QR للطباعة**: يعرض رابط الملف المخصص على
  ملصق أبيض بعرض 58 مم ويحفظه صورةً PNG في معرض الهاتف عبر `gal`.
- `lib/screens/writer_screen.dart` — كتابة الرابط على شريحة NFC والتحقق والقفل.
- `lib/core/storage_service.dart` — فحص صيغة الصورة من محتواها، اختيار الحاوية،
  الرفع والحذف وأخطاء الرفع بالعربية.
- `supabase/migrations/` — المخطط والسياسات ودالة العرض العامة، بما فيها إضافة
  `image_url` وحاوية الصور.
- `web_profiles/` — صفحة العرض العامة (Vercel / Netlify / Cloudflare Pages).

## التشغيل والبناء

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=config.json
flutter build apk --release --dart-define-from-file=config.json
```

ملف `config.json` يحتوي `SUPABASE_URL` و`SUPABASE_ANON_KEY` (مفتاح publishable
عام) و`PUBLIC_PROFILE_BASE_URL`، ويمكن إضافة `SUPABASE_STORAGE_BUCKET` لتحديد اسم
حاوية الصور صراحةً.

بناء الـ APK عبر GitHub Actions: شغّل workflow «Build Flutter APK» يدوياً أو بدفع
commit إلى `main`، ثم نزّل artifact باسم `nfc-admin-app-apk`.

## المكتبات المضافة

- `image_picker` — اختيار صورة الملف من معرض الهاتف.
- `qr_flutter` — توليد رمز QR للرابط المخصص.
- `gal` — حفظ صورة الملصق في معرض الهاتف لطباعتها حرارياً.

## الوثائق

راجع [DEPLOYMENT.md](DEPLOYMENT.md) لخطوات نشر الويب وتهيئة Supabase والحاوية
وسياسات الأمان وحدود الاستخدام.
