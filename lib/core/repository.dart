import 'package:supabase_flutter/supabase_flutter.dart';

typedef Json = Map<String, dynamic>;

class Repository {
  Repository(this.client);
  final SupabaseClient client;
  Future<List<Json>> rows(String table, {String? tenant}) async {
    final output = <Json>[];
    for (var offset = 0; ; offset += 500) {
      var q = client.from(table).select();
      if (tenant != null) q = q.eq('tenant_id', tenant);
      final page = await q
          .order(table == 'nfc_memberships' ? 'user_id' : 'id')
          .range(offset, offset + 499);
      output.addAll(page.map((e) => Map<String, dynamic>.from(e)));
      if (page.length < 500) return output;
    }
  }

  Future<Json> profile(String id, String tenant) async =>
      Map<String, dynamic>.from(
        await client
            .from('nfc_profiles')
            .select()
            .eq('id', id)
            .eq('tenant_id', tenant)
            .single(),
      );
  /// Inserts or updates [fields]. Returns the row id so callers can upload an
  /// image right after a new profile is created.
  Future<String?> save(String table, Json fields, {String? id}) async {
    if (id == null) {
      final inserted = await client
          .from(table)
          .insert(fields)
          .select('id')
          .single();
      return inserted['id'] as String?;
    }
    await client.from(table).update(fields).eq('id', id);
    return id;
  }

  Future<void> delete(String table, String id) async {
    await client.from(table).delete().eq('id', id);
  }

  Future<int> count(String table, String tenant) async =>
      await client.from(table).count(CountOption.exact).eq('tenant_id', tenant);
  Future<bool> amSuperAdmin() async {
    try {
      return await client.rpc('nfc_am_super_admin') == true;
    } catch (_) {
      return false;
    }
  }

  /// Sets (6-12 digits) or clears (empty) the PIN the card owner uses to edit
  /// their public page.
  Future<void> setProfilePin(String profileId, String pin) async {
    await client.rpc(
      'nfc_set_profile_pin',
      params: {'target_profile': profileId, 'pin': pin},
    );
  }

  Future<bool> profileHasPin(String profileId) async {
    try {
      final rows = await client.rpc(
        'nfc_profile_pin_status',
        params: {
          'profile_ids': [profileId],
        },
      );
      return rows is List && rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Free-form audit event (login, QR saved, worker management...). The server
  /// forces the actor to be the signed-in user.
  Future<void> logEvent(
    String tenant,
    String action, {
    String? subject,
  }) async {
    try {
      await client.rpc(
        'nfc_log_event',
        params: {
          'workspace_id': tenant,
          'event_action': action,
          'event_subject': subject,
        },
      );
    } catch (_) {
      // Auditing must never block the user's action.
    }
  }

  Future<void> log(String tenant, String profile, String action) async {
    await client.from('nfc_write_events').insert({
      'tenant_id': tenant,
      'profile_id': profile,
      'action': action,
    });
  }
}

String userError(Object e) {
  if (e is AuthException) return e.message;
  if (e is PostgrestException && e.code == '23505') {
    return 'هذا الاسم المخصص مستخدم أو محجوز سابقاً.';
  }
  if (e is PostgrestException && (e.code == '42703' || e.code == 'PGRST204')) {
    return 'قاعدة البيانات لا تحتوي الحقل المطلوب. طبّق ملفات '
        'supabase/migrations على مشروع Supabase أولاً.';
  }
  if (e is PostgrestException) return 'تعذّر حفظ/قراءة البيانات: ${e.message}';
  return e.toString();
}

const kindNames = {
  'vcard': 'بطاقة اتصال · vCard',
  'menu': 'قائمة · Menu',
  'review': 'تقييم Google',
  'equipment': 'معدّة · Equipment',
  'loyalty': 'ولاء · Loyalty',
};
const fieldsByKind = {
  'vcard': {
    'full_name': 'الاسم الكامل *',
    'phone': 'الهاتف',
    'email': 'البريد',
    'website': 'الموقع HTTPS',
  },
  'menu': {'menu_url': 'رابط القائمة HTTPS *'},
  'review': {'review_url': 'رابط التقييم HTTPS *'},
  'equipment': {
    'equipment_name': 'اسم المعدّة *',
    'serial': 'الرقم التسلسلي',
    'manual_url': 'دليل التشغيل HTTPS',
  },
  'loyalty': {
    'loyalty_url': 'رابط برنامج الولاء HTTPS *',
    'terms': 'الشروط العامة',
  },
};
bool validHttps(String value) {
  final u = Uri.tryParse(value);
  return u != null &&
      u.scheme == 'https' &&
      u.host.isNotEmpty &&
      u.userInfo.isEmpty &&
      !RegExp(r'\s').hasMatch(value);
}
