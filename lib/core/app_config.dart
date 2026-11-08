import 'i18n.dart';
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  // Both names are public client keys. The legacy name remains supported.
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );
  // Origin only, e.g. https://cards.customer-domain.com. Never an index.html URL.
  static const profileBase = String.fromEnvironment('PUBLIC_PROFILE_BASE_URL');
  // Storage bucket that holds profile images. Leave empty to auto-detect the
  // bucket at runtime and fall back to 'profile-images'.
  static const storageBucket = String.fromEnvironment('SUPABASE_STORAGE_BUCKET');
  // Hard limit enforced by the app; keep it in sync with the bucket limit.
  static const imageMaxBytes = 5 * 1024 * 1024;
  static const reservedSlugs = {
    'admin',
    'api',
    'assets',
    'auth',
    'login',
    'logout',
    'settings',
    'www',
    'new',
  };
  // Field-worker accounts authenticate with a username; the app maps it to this
  // synthetic address, which is exactly what supabase/functions/admin-workers
  // creates. Real e-mail logins keep working unchanged.
  static const workerDomain = 'workers.nfc-studio.internal';
  static String? loginEmail(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;
    if (value.contains('@')) return value.toLowerCase();
    return '${value.toLowerCase()}@$workerDomain';
  }

  static bool validSlug(String s) =>
      s.length >= 3 &&
      s.length <= 63 &&
      RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(s) &&
      !reservedSlugs.contains(s);
  static Uri profileUrl(String base, String slug) {
    final uri = Uri.tryParse(base.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.hasFragment ||
        uri.hasQuery ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw FormatException(
        tr('أدخل أصل نطاق HTTPS فقط، مثل https://cards.example.com'),
      );
    }
    if (!validSlug(slug)) {
      throw FormatException(
        tr('الاسم: 3–63 حرفاً، a-z و0-9 وشرطات مفردة فقط'),
      );
    }
    return uri.replace(path: '/p/$slug', query: null, fragment: null);
  }
}
