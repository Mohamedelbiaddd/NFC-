import 'dart:math';
import 'i18n.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'repository.dart';

/// Loyalty shops: creation by field agents, owner passwords and counters.
class ShopsService {
  ShopsService(this.client);

  final SupabaseClient client;

  static Map<String, (String, String)> get industries => <String, (String, String)>{
    'barber': ('✂️', tr('حلاقة')),
    'beauty': ('💅', tr('تجميل')),
    'carwash': ('🚗', tr('غسيل سيارات')),
    'bakery': ('🥐', tr('مخبزة')),
    'cafe': ('☕', tr('مقهى')),
    'snack': ('🍕', tr('سناك / بيتزاريا')),
    'gym': ('🏋️', tr('قاعة رياضة')),
    'other': ('⭐', tr('نشاط آخر')),
  };

  static String _base() {
    var base = AppConfig.profileBase.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  /// Browser dashboard for the shop owner.
  static String ownerLink(String slug) => '${_base()}/s/$slug';

  /// Page customers open (join + loyalty card).
  static String customerLink(String slug) => '${_base()}/c/$slug';

  static String randomPassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final r = Random.secure();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Latin slug from the shop name, with a random suffix so it is unique.
  static String slugFor(String name) {
    final base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final r = Random.secure();
    final suffix = List.generate(4, (_) => '0123456789abcdefghijklmnopqrstuvwxyz'[r.nextInt(36)]).join();
    final head = base.length > 40 ? base.substring(0, 40).replaceAll(RegExp(r'-+$'), '') : base;
    return head.length >= 3 ? '$head-$suffix' : 'shop-$suffix';
  }

  Future<List<Json>> overview(String? workspaceId) async {
    final rows = await client.rpc(
      'nfc_shops_overview',
      params: {'workspace_id': workspaceId},
    );
    return rows is List
        ? rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Json>[];
  }

  /// Creates the business row and turns on loyalty.
  Future<({String id, String slug, String password})> create({
    required String tenant,
    required String name,
    required String industry,
    required int goal,
    required String reward,
    String? phone,
    String? address,
    String? hours,
    (double, double)? location,
    int radius = 200,
    String theme = 'navy',
  }) async {
    final row = await client
        .from('nfc_businesses')
        .insert({
          'tenant_id': tenant,
          'name': name,
          'industry': industry,
          'phone': _blank(phone),
          'address': _blank(address),
          'hours': _blank(hours),
          'latitude': location?.$1,
          'longitude': location?.$2,
          'geofence_radius_m': radius,
          'theme': theme,
        })
        .select('id')
        .single();
    final password = randomPassword();
    final slug = slugFor(name);
    await setup(
      businessId: '${row['id']}',
      slug: slug,
      goal: goal,
      reward: reward,
      password: password,
    );
    return (id: '${row['id']}', slug: slug, password: password);
  }

  /// Edits shop details through an RPC so managers higher in the network
  /// (whose shops live in another workspace) can edit them too.
  Future<void> update({
    required String businessId,
    required String name,
    required String industry,
    String? phone,
    String? address,
    String? hours,
    (double, double)? location,
    int radius = 200,
    String? theme,
  }) async {
    await client.rpc(
      'nfc_shop_edit',
      params: {
        'target': businessId,
        'settings': {
          'name': name,
          'industry': industry,
          'phone': phone ?? '',
          'address': address ?? '',
          'hours': hours ?? '',
          'radius_m': '$radius',
          if (theme != null) 'theme': theme,
          if (location != null) 'latitude': '${location.$1}',
          if (location != null) 'longitude': '${location.$2}',
        },
      },
    );
  }

  /// The shop's loyalty card design (null if this user may not edit it).
  Future<String?> theme(String businessId) async {
    final r = await client.rpc('nfc_shop_theme', params: {'target': businessId});
    return r is String ? r : null;
  }

  Future<void> setup({
    required String businessId,
    required String slug,
    required int goal,
    required String reward,
    String? password,
  }) async {
    await client.rpc(
      'nfc_shop_setup',
      params: {
        'target_business': businessId,
        'slug': slug,
        'goal': goal,
        'reward': reward,
        'owner_password': password,
      },
    );
  }

  Future<void> setDisabled(String businessId, bool disabled) async {
    await client.rpc(
      'nfc_shop_disable',
      params: {'target_business': businessId, 'disabled': disabled},
    );
  }

  /// Accepts "33.57, -7.59" or a Google Maps link containing @lat,lng / q=lat,lng.
  /// Coordinates written in the text itself: "33.57, -7.58", "33.57 -7.58",
  /// a Google Maps long link (marker !3d..!4d.., q=, ll=, @) or 33°34'23"N 7°35'23"W.
  static (double, double)? parseLocation(String text) {
    var t = text.trim();
    try {
      t = Uri.decodeFull(t);
    } catch (_) {}
    t = t.replaceAll('+', ' ');
    const n = r'(-?\d{1,3}(?:\.\d+)?)';
    final patterns = [
      RegExp('!3d$n!4d$n'),
      RegExp(r'[?&](?:q|query|ll|sll|daddr|destination|center)=(?:loc:)?\s*' + n + r'\s*,\s*' + n),
      RegExp('geo:$n,$n'),
      RegExp('@$n,$n'),
      RegExp(r'^\s*' + n + r'\s*[,;\s]\s*' + n + r'\s*$'),
      RegExp(n + r'\s*,\s*' + n),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(t);
      if (m == null) continue;
      final lat = double.tryParse(m.group(1)!), lng = double.tryParse(m.group(2)!);
      if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180 && !(lat == 0 && lng == 0)) {
        return (lat, lng);
      }
    }
    final dms = RegExp(
      r'(\d{1,2})°\s*(\d{1,2})[' "'" r'′]\s*(\d{1,2}(?:\.\d+)?)?["″]?\s*([NS])[\s,]*(\d{1,3})°\s*(\d{1,2})[' "'" r'′]\s*(\d{1,2}(?:\.\d+)?)?["″]?\s*([EW])',
      caseSensitive: false,
    ).firstMatch(t);
    if (dms != null) {
      double v(String d, String m, String? s) => double.parse(d) + double.parse(m) / 60 + (double.tryParse(s ?? '') ?? 0) / 3600;
      final lat = v(dms.group(1)!, dms.group(2)!, dms.group(3)) * (dms.group(4)!.toUpperCase() == 'S' ? -1 : 1);
      final lng = v(dms.group(5)!, dms.group(6)!, dms.group(7)) * (dms.group(8)!.toUpperCase() == 'W' ? -1 : 1);
      return (lat, lng);
    }
    return null;
  }

  /// Any location the staff pastes: the above, plus short Maps links
  /// (maps.app.goo.gl…) and Plus Codes (8C5JHCF6+63, or HCF6+63 Casablanca),
  /// resolved by the geo-resolve function. [near]: the shop's town/address.
  Future<(double, double)?> resolveLocation(String text, {String near = ''}) async {
    final local = parseLocation(text);
    // A link whose coordinates are not in the address itself (short link).
    final shortLink = RegExp(r'https?://').hasMatch(text) && !RegExp(r'!3d|@-?\d|[?&](q|ll|query)=-?\d').hasMatch(text);
    if (local != null && !shortLink) return local;
    try {
      final res = await client.functions
          .invoke('geo-resolve', body: {'q': text.trim(), 'near': near.trim()})
          .timeout(const Duration(seconds: 25));
      final d = res.data;
      if (d is Map && d['lat'] is num && d['lng'] is num) {
        return ((d['lat'] as num).toDouble(), (d['lng'] as num).toDouble());
      }
    } catch (_) {}
    return shortLink ? null : local;
  }

  static String? _blank(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }
}
