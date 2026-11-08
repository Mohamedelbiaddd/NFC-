import 'package:supabase_flutter/supabase_flutter.dart';

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
      throw NetworkException(e.status == 403 ? 'لا تملك صلاحية هذه العملية.' : 'فشل الطلب (رمز ${e.status}).');
    } catch (e) {
      if (e is NetworkException) rethrow;
      final match = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(e.toString());
      throw NetworkException(match?.group(1) ?? 'تعذّر تنفيذ الطلب. تحقق من الاتصال.');
    }
  }

  /// Returns the generated password.
  Future<String> create({required String email, required String name, required String role}) async {
    final result = await _call({'action': 'create', 'email': email, 'name': name, 'role': role});
    return '${result['password']}';
  }

  Future<String> resetPassword(String userId) async {
    final result = await _call({'action': 'reset_password', 'user_id': userId});
    return '${result['password']}';
  }

  Future<void> delete(String userId) async {
    await _call({'action': 'delete', 'user_id': userId});
  }
}

/// green = paid this month, red = expired, grey = never paid.
String statusLabel(String? status) => switch (status) {
  'paid' => 'مدفوع',
  'expired' => 'منتهي',
  _ => 'لم يدفع بعد',
};

class NetworkException implements Exception {
  const NetworkException(this.message);
  final String message;
  @override
  String toString() => message;
}
