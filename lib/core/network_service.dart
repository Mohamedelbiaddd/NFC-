import 'package:supabase_flutter/supabase_flutter.dart';
import 'i18n.dart';

import 'repository.dart';

/// Staff network (admin -> agents -> workers), subscriptions and suspension.
class NetworkService {
  NetworkService(this.client);

  final SupabaseClient client;

  List<Json> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Json>[];

  Future<Json> myAccount() async {
    final value = await client.rpc('nfc_my_account');
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  Future<List<Json>> members() async => _rows(await client.rpc('nfc_network_members'));

  Future<List<Json>> shops() async => _rows(await client.rpc('nfc_network_shops'));

  Future<List<Json>> events({int max = 100}) async =>
      _rows(await client.rpc('nfc_network_events_feed', params: {'max_rows': max}));

  Future<void> markPaid(String subject, String id, {int months = 1}) async {
    await client.rpc('nfc_mark_paid', params: {'subject': subject, 'target': id, 'months': months});
  }

  Future<void> undoPayment(String subject, String id) async {
    await client.rpc('nfc_undo_payment', params: {'subject': subject, 'target': id});
  }

  Future<void> setShopSuspended(String id, bool value) async {
    await client.rpc('nfc_set_shop_suspended', params: {'target': id, 'value': value});
  }

  Future<void> setStaffActive(String id, bool value, {bool includeShops = false}) async {
    await client.rpc(
      'nfc_set_staff_active',
      params: {'target': id, 'value': value, 'include_shops': includeShops},
    );
  }

  /// Shows (or clears with an empty message) a payment notice to a shop owner
  /// or a staff member. Nothing is ever sent automatically.
  Future<void> setNotice(String subject, String id, String message) async {
    await client.rpc('nfc_set_notice', params: {'subject': subject, 'target': id, 'message': message});
  }

  Future<Json> _call(Map<String, dynamic> body) async {
    try {
      final response = await client.functions.invoke('staff-admin', body: body);
      final data = response.data;
      if (data is Map && data['error'] != null) throw NetworkException('${data['error']}');
      return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) throw NetworkException('${details['error']}');
      throw NetworkException(e.status == 403 ? tr('لا تملك صلاحية هذه العملية.') : trf('فشل الطلب (رمز {0}).', [e.status]));
    } catch (e) {
      if (e is NetworkException) rethrow;
      final match = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(e.toString());
      throw NetworkException(match?.group(1) ?? tr('تعذّر تنفيذ الطلب. تحقق من الاتصال.'));
    }
  }

  /// Creates the account and its invitation (24 h link + code, e-mailed
  /// when the server can). Nobody sees a password.
  Future<Json> create({required String email, required String name, required String role}) =>
      _call({'action': 'create', 'email': email, 'name': name, 'role': role, 'lang': appLang.value});

  /// New invitation link (the previous one stops working).
  Future<Json> invite(String userId) =>
      _call({'action': 'invite', 'user_id': userId, 'lang': appLang.value});

  /// Invitation state and phone of every member I manage, by user id.
  Future<Map<String, Json>> devices() async {
    final rows = _rows(await client.rpc('nfc_network_devices'));
    return {for (final r in rows) '${r['user_id']}': r};
  }

  /// Invitation and phones of one member.
  Future<Json> security(String userId) async {
    final value = await client.rpc('nfc_staff_security', params: {'target': userId});
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  Future<void> decideDevice(String deviceId, bool approve) async =>
      _ok(await client.rpc('nfc_device_decide', params: {'p_id': deviceId, 'p_approve': approve}));

  /// Forgets the member's phone: the next phone that logs in becomes it.
  Future<void> resetDevice(String userId) async =>
      _ok(await client.rpc('nfc_device_reset', params: {'target': userId}));

  Future<void> delete(String userId) async {
    await _call({'action': 'delete', 'user_id': userId});
  }

  /// Deletes the account with everything it created (shops, cards,
  /// workspaces) and its login; [withTeam] also removes everyone under it.
  Future<int> purge(String userId, {bool withTeam = false}) async {
    final result = await _call({'action': 'purge', 'user_id': userId, 'with_children': withTeam});
    return (result['removed'] as num?)?.toInt() ?? 0;
  }

  /// Super admin: may this agent add people / manage them.
  Future<void> setPermissions(String userId, {bool? canAdd, bool? canManage}) async {
    _ok(await client.rpc('nfc_admin_set_staff_perms',
        params: {'target': userId, 'can_add': canAdd, 'can_manage': canManage}));
  }

  Future<void> deleteShop(String shopId) async =>
      _ok(await client.rpc('nfc_admin_delete_shop', params: {'target': shopId}));

  Future<void> deleteProfile(String profileId) async =>
      _ok(await client.rpc('nfc_admin_delete_profile', params: {'target': profileId}));

  Future<int> deleteProfilesOf(String userId) async {
    final r = await client.rpc('nfc_admin_delete_profiles_of', params: {'owner': userId});
    _ok(r);
    return r is Map ? ((r['deleted'] as num?)?.toInt() ?? 0) : 0;
  }

  void _ok(dynamic r) {
    if (r is Map && r['ok'] == true) return;
    final error = r is Map ? '${r['error']}' : '';
    throw NetworkException(switch (error) {
      'forbidden' => tr('لا تملك صلاحية هذه العملية.'),
      'not_found' => tr('غير موجود (ربما حُذف من قبل).'),
      _ => tr('تعذّر تنفيذ الطلب. تحقق من الاتصال.'),
    });
  }
}

/// green = paid this month, red = expired, grey = never paid.
String statusLabel(String? status) => switch (status) {
  'paid' => tr('مدفوع'),
  'expired' => tr('منتهي'),
  _ => tr('لم يدفع بعد'),
};

class NetworkException implements Exception {
  const NetworkException(this.message);
  final String message;
  @override
  String toString() => message;
}
