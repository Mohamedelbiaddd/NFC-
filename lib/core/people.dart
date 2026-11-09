import 'repository.dart';
import 'i18n.dart';

/// Reads a string field from a profile's JSONB `data` object.
String profileField(Json profile, String key) {
  final data = profile['data'];
  if (data is Map) {
    final value = data[key];
    if (value is String) return value.trim();
  }
  return '';
}

String personName(Json profile) {
  final full = profileField(profile, 'full_name');
  if (full.isNotEmpty) return full;
  final title = profile['title'];
  if (title is String && title.trim().isNotEmpty) return title.trim();
  return tr('بدون اسم');
}

String personTitle(Json profile) {
  final title = profile['title'];
  if (title is String && title.trim().isNotEmpty) return title.trim();
  return personName(profile);
}

String personPhone(Json p) => profileField(p, 'phone');
String personEmail(Json p) => profileField(p, 'email');
String personWebsite(Json p) => profileField(p, 'website');

String personImage(Json p) {
  final value = p['image_url'];
  return value is String && value.startsWith('https://') ? value : '';
}

String personSlug(Json p) {
  final value = p['custom_slug'];
  return value is String ? value : '';
}

bool personPublished(Json p) => p['published'] == true;

String personInitial(Json p) {
  final name = personName(p).trim();
  return name.isEmpty ? '?' : name.substring(0, 1);
}

String kindLabel(Json p) => kindNames['${p['kind']}'] ?? tr('بطاقة');
