import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';

/// A validated image payload with the extension and MIME type that match the
/// real bytes, so a renamed file can never be uploaded with a wrong type.
class ImagePayload {
  const ImagePayload({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String extension;
  final String contentType;

  int get length => bytes.length;
}

/// Detects PNG / JPEG / WebP from magic bytes. Returns null for anything else
/// (including files larger than [AppConfig.imageMaxBytes]).
ImagePayload? decodeImagePayload(Uint8List bytes) {
  if (bytes.length < 12 || bytes.length > AppConfig.imageMaxBytes) return null;
  const png = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (_matchesAt(bytes, 0, png)) {
    return ImagePayload(
      bytes: bytes,
      extension: 'png',
      contentType: 'image/png',
    );
  }
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return ImagePayload(
      bytes: bytes,
      extension: 'jpg',
      contentType: 'image/jpeg',
    );
  }
  const riff = <int>[0x52, 0x49, 0x46, 0x46];
  const webp = <int>[0x57, 0x45, 0x42, 0x50];
  if (_matchesAt(bytes, 0, riff) && _matchesAt(bytes, 8, webp)) {
    return ImagePayload(
      bytes: bytes,
      extension: 'webp',
      contentType: 'image/webp',
    );
  }
  return null;
}

bool _matchesAt(Uint8List bytes, int offset, List<int> pattern) {
  if (bytes.length < offset + pattern.length) return false;
  for (var i = 0; i < pattern.length; i++) {
    if (bytes[offset + i] != pattern[i]) return false;
  }
  return true;
}

/// Uploads profile images to a public Supabase Storage bucket and returns the
/// public URL that is stored in `nfc_profiles.image_url`.
///
/// Objects live under `<tenant_id>/<profile_id>/<timestamp>.<ext>` so the
/// storage policies from `supabase/migrations` can authorise the upload from
/// the tenant id alone.
class ProfileImageStorage {
  ProfileImageStorage(this.client);

  final SupabaseClient client;

  /// Bucket names tried in order when SUPABASE_STORAGE_BUCKET is not supplied.
  static const preferredBuckets = <String>[
    'profile-images',
    'profile_images',
    'profileimages',
    'profiles',
    'avatars',
    'images',
    'media',
  ];
  static const fallbackBucket = 'profile-images';

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
  );

  String? _bucket;

  /// The bucket resolved for the last upload, when known.
  String? get bucket => _bucket;

  /// Resolves the bucket once and caches it. An explicit dart-define always
  /// wins; otherwise the public buckets of the project are inspected and the
  /// first sensible name is used.
  Future<String> resolveBucket() async {
    final cached = _bucket;
    if (cached != null) return cached;
    final configured = AppConfig.storageBucket.trim();
    if (configured.isNotEmpty) return _bucket = configured;
    try {
      final buckets = await client.storage.listBuckets();
      for (final name in preferredBuckets) {
        for (final b in buckets) {
          if (b.id == name || b.name == name) return _bucket = b.id;
        }
      }
      for (final b in buckets) {
        if (b.id.toLowerCase().contains('profile')) return _bucket = b.id;
      }
      final publicBuckets = buckets.where((b) => b.public).toList();
      if (publicBuckets.length == 1) return _bucket = publicBuckets.first.id;
      if (buckets.length == 1) return _bucket = buckets.first.id;
    } catch (_) {
      // Listing buckets may be blocked by a restrictive storage policy; the
      // fallback name is still worth trying for the upload itself.
    }
    return _bucket = fallbackBucket;
  }

  Future<String> uploadImage({
    required String tenantId,
    required String profileId,
    required ImagePayload payload,
  }) async {
    _requireId(tenantId);
    _requireId(profileId);
    final id = await resolveBucket();
    final path =
        '$tenantId/$profileId/'
        '${DateTime.now().millisecondsSinceEpoch}.${payload.extension}';
    await client.storage
        .from(id)
        .uploadBinary(
          path,
          payload.bytes,
          fileOptions: FileOptions(
            contentType: payload.contentType,
            upsert: false,
          ),
        );
    return client.storage.from(id).getPublicUrl(path);
  }

  /// Best-effort removal of a previously uploaded image. Never throws; orphans
  /// are harmless, a failed cleanup must not block saving the profile.
  Future<void> deleteImage(String publicUrl) async {
    try {
      final bucketId = _bucket != null ? _bucket! : await resolveBucket();
      final marker = '/storage/v1/object/public/$bucketId/';
      final index = publicUrl.indexOf(marker);
      if (index < 0) return;
      final raw = publicUrl.substring(index + marker.length).split('?').first;
      final path = Uri.decodeComponent(raw);
      if (path.isEmpty || path.contains('..')) return;
      await client.storage.from(bucketId).remove([path]);
    } catch (_) {
      // Ignore: the profile row no longer references the object.
    }
  }

  void _requireId(String value) {
    if (!_uuid.hasMatch(value)) {
      throw const FormatException('معرّف مساحة العمل أو الملف غير صالح.');
    }
  }
}

/// Turns raw storage/PostgREST failures into an Arabic message the operator can
/// act on (bad bucket name, missing policy, oversize file...).
String imageUploadError(Object e) {
  if (e is FormatException) return e.message;
  final text = e.toString().toLowerCase();
  if (text.contains('bucket not found') || text.contains('bucket_not_found')) {
    return 'حاوية التخزين غير موجودة. أنشئ Bucket عاماً باسم profile-images، '
        'أو مرّر SUPABASE_STORAGE_BUCKET عند البناء.';
  }
  if (text.contains('row-level security') ||
      text.contains('unauthorized') ||
      text.contains('403') ||
      text.contains('policy')) {
    return 'رفض الخادم رفع الصورة. تحقق من سياسات Storage في Supabase '
        'ومن صلاحية عضويتك في مساحة العمل.';
  }
  if (text.contains('too large') ||
      text.contains('maximum') ||
      text.contains('413')) {
    return 'حجم الصورة يتجاوز الحد المسموح في الحاوية (5 ميجابايت).';
  }
  if (text.contains('mime') || text.contains('content type')) {
    return 'صيغة الصورة غير مسموحة في الحاوية. استخدم JPG أو PNG أو WebP.';
  }
  return 'تعذّر رفع الصورة: $e';
}
