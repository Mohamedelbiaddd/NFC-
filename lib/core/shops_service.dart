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
          if (location != null) 'latitude': '${location.$1}',
          if (location != null) 'longitude': '${location.$2}',
        },
      },
    );
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
  static (double, double)? parseLocation(String text) {
    final match = RegExp(r'(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)').firstMatch(text);
    if (match == null) return null;
    final lat = double.tryParse(match.group(1)!), lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) return null;
    return (lat, lng);
  }

  static String? _blank(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }
}
