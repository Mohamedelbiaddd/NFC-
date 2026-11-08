import 'package:supabase_flutter/supabase_flutter.dart';

import 'repository.dart';

/// A readable failure coming from an Edge Function or the database.
class WorkerException implements Exception {
  WorkerException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Team accounts and the audit trail. Both are served by SECURITY DEFINER RPCs
/// so a worker never sees another workspace's data.
class WorkersService {
  WorkersService(this.client);

  final SupabaseClient client;

  Future<List<Json>> overview(String tenant) async => _rows(
    await client.rpc('nfc_team_overview', params: {'workspace_id': tenant}),
  );

  Future<List<Json>> activity(String tenant, {int limit = 120}) async => _rows(
    await client.rpc(
      'nfc_activity_feed',
      params: {'workspace_id': tenant, 'max_rows': limit},
    ),
  );

  Future<void> createWorker({
    required String tenant,
    required String username,
    required String displayName,
    required String password,
    String role = 'editor',
  }) => _invoke({
    'action': 'create',
    'workspace_id': tenant,
    'username': username,
    'display_name': displayName,
    'password': password,
    'role': role,
  });

  Future<void> resetPassword({
    required String tenant,
    required String workerId,
    required String password,
  }) => _invoke({
    'action': 'reset_password',
    'workspace_id': tenant,
    'worker_id': workerId,
    'password': password,
  });

  Future<void> setDisabled({
    required String tenant,
    required String workerId,
    required bool disabled,
  }) => _invoke({
    'action': 'set_disabled',
    'workspace_id': tenant,
    'worker_id': workerId,
    'disabled': disabled,
  });

  Future<void> deleteWorker({
    required String tenant,
    required String workerId,
  }) => _invoke({
    'action': 'delete',
    'workspace_id': tenant,
    'worker_id': workerId,
  });

  Future<Json> _invoke(Map<String, dynamic> body) async {
    try {
      final response = await client.functions.invoke(
        'admin-workers',
        body: body,
      );
      final data = response.data;
      if (response.status >= 400) {
        throw WorkerException(_errorMessage(data, response.status));
      }
      return data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
    } catch (e) {
      if (e is WorkerException) rethrow;
      final match = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(e.toString());
      throw WorkerException(
        match?.group(1) ??
            'تعذّر تنفيذ الطلب. تحقق من الاتصال ثم أعد المحاولة.',
      );
    }
  }

  String _errorMessage(dynamic data, int status) {
    if (data is Map && data['error'] != null) return '${data['error']}';
    if (status == 401) return 'انتهت الجلسة. سجّل الدخول من جديد.';
    if (status == 403) return 'لا تملك صلاحية هذه العملية.';
    return 'فشل الطلب (رمز $status).';
  }

  List<Json> _rows(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }
}
