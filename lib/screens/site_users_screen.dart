import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

typedef _Json = Map<String, dynamic>;

/// Super admin only: people who signed up on the website (tapmaroc.com/start)
/// for a free card. See who they are, what they did (card edits, scans,
/// sign-ins with IP), and block them, hide their card, give them a new
/// password or delete them. The database refuses all of this for anyone
/// else, and never touches staff accounts.
class SiteUsersScreen extends StatefulWidget {
  const SiteUsersScreen({super.key, required this.client});

  final SupabaseClient client;

  @override
  State<SiteUsersScreen> createState() => _SiteUsersScreenState();
}

class _SiteUsersScreenState extends State<SiteUsersScreen> {
  final search = TextEditingController();
  List<_Json> users = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await widget.client.rpc('nfc_site_users', params: {'term': search.text.trim()});
      final list = (res is List ? res : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (mounted) setState(() => users = list);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  static String _date(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (d == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  static int _int(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  String _cardUrl(String slug) {
    var base = AppConfig.profileBase.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base/p/$slug';
  }

  void _snack(String text, {bool bad = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: bad ? AppColors.danger : null),
    );
  }

  Future<bool> _confirm(String title, String body, {bool danger = true}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('إلغاء'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: danger ? AppColors.danger : AppColors.success),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('تأكيد')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _act(_Json u, String what) async {
    final email = '${u['email'] ?? ''}';
    switch (what) {
      case 'block':
        if (!await _confirm(tr('حظر هذا الشخص؟'), trf('لن يستطيع «{0}» الدخول، وستُخفى بطاقته. يمكنك فك الحظر في أي وقت.', [email]))) return;
      case 'delete':
        if (!await _confirm(tr('حذف الحساب نهائياً؟'), trf('سيُحذف حساب «{0}» وبطاقته نهائياً، ولا يمكن التراجع.', [email]))) return;
      case 'reset_password':
        if (!await _confirm(tr('كلمة مرور جديدة؟'), trf('ستُلغى كلمة مرور «{0}» الحالية ويخرج من كل أجهزته.', [email]), danger: false)) return;
    }
    try {
      final res = await widget.client.rpc('nfc_site_user_action', params: {'target': u['id'], 'what': what});
      if (!mounted) return;
      if (what == 'reset_password' && res is Map && res['password'] != null) {
        await _showPassword(email, '${res['password']}');
      } else {
        _snack(tr('تم ✓'));
      }
      await load();
    } catch (e) {
      if (mounted) _snack('$e', bad: true);
    }
  }

  Future<void> _showPassword(String email, String pw) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('كلمة المرور الجديدة')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(email, textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 10),
              SelectableText(pw, textDirection: TextDirection.ltr, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Text(tr('أرسلها له، ويمكنه تغييرها بعد الدخول.'), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Clipboard.setData(ClipboardData(text: pw)),
              icon: const Icon(Icons.copy_rounded),
              label: Text(tr('نسخ')),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('تم'))),
          ],
        ),
      );

  static String _kindLabel(String kind) {
    switch (kind) {
      case 'profile_created':
        return tr('أنشأ بطاقته');
      case 'owner_edited':
      case 'profile_updated':
        return tr('عدّل بطاقته');
      case 'profile_deleted':
        return tr('حُذفت البطاقة');
      case 'scans':
        return tr('زيارات البطاقة');
      case 'auth_user_signedup':
        return tr('أنشأ الحساب');
      case 'auth_user_confirmation_requested':
        return tr('طُلب تفعيل البريد');
      case 'auth_login':
        return tr('تسجيل دخول');
      case 'auth_logout':
        return tr('تسجيل خروج');
      case 'auth_token_refreshed':
      case 'auth_token_revoked':
        return tr('تجديد الجلسة');
      case 'auth_user_recovery_requested':
        return tr('طلب تغيير كلمة المرور');
      case 'auth_user_updated_password':
      case 'auth_user_modified':
        return tr('غيّر كلمة المرور أو بياناته');
      default:
        return kind;
    }
  }

  static IconData _kindIcon(String kind) {
    if (kind == 'scans') return Icons.visibility_rounded;
    if (kind.startsWith('auth_login') || kind.startsWith('auth_token')) return Icons.login_rounded;
    if (kind.startsWith('auth_')) return Icons.person_rounded;
    return Icons.edit_rounded;
  }

  Future<void> _openLog(_Json u) async {
    List<_Json> log = const [];
    String? err;
    try {
      final res = await widget.client.rpc('nfc_site_user_log', params: {'target': u['id']});
      log = (res is List ? res : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      err = '$e';
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(trf('سجلّ «{0}»', ['${u['email']}']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Expanded(
              child: err != null
                  ? Center(child: Text(err))
                  : log.isEmpty
                      ? Center(child: Text(tr('لا توجد عمليات بعد.')))
                      : ListView.separated(
                          controller: controller,
                          itemCount: log.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final e = log[i];
                            final kind = '${e['kind'] ?? ''}';
                            final detail = '${e['detail'] ?? ''}';
                            return ListTile(
                              dense: true,
                              leading: Icon(_kindIcon(kind), color: AppColors.muted),
                              title: Text(_kindLabel(kind)),
                              subtitle: Text(
                                [_date(e['at']), if (detail.isNotEmpty) (kind.startsWith('auth_') ? 'IP $detail' : detail)].join(' · '),
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.start,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUser(_Json u) async {
    final slug = '${u['slug'] ?? ''}';
    final banned = u['banned'] == true;
    final published = u['published'] == true;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('${u['email']}', textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(trf('سجّل في {0} · آخر دخول {1}', [_date(u['created_at']), _date(u['last_sign_in_at'])])),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(tr('سجلّ ما فعله')),
              onTap: () {
                Navigator.pop(context);
                _openLog(u);
              },
            ),
            if (slug.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: Text(tr('فتح بطاقته')),
                subtitle: Text(_cardUrl(slug), textDirection: TextDirection.ltr),
                onTap: () {
                  Navigator.pop(context);
                  launchUrl(Uri.parse(_cardUrl(slug)), mode: LaunchMode.externalApplication);
                },
              ),
            if (slug.isNotEmpty && !banned)
              ListTile(
                leading: Icon(published ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                title: Text(published ? tr('إخفاء بطاقته') : tr('إظهار بطاقته')),
                onTap: () {
                  Navigator.pop(context);
                  _act(u, published ? 'hide_card' : 'show_card');
                },
              ),
            ListTile(
              leading: const Icon(Icons.key_rounded),
              title: Text(tr('إعطاؤه كلمة مرور جديدة')),
              onTap: () {
                Navigator.pop(context);
                _act(u, 'reset_password');
              },
            ),
            ListTile(
              leading: Icon(banned ? Icons.lock_open_rounded : Icons.block_rounded, color: banned ? AppColors.success : AppColors.warning),
              title: Text(banned ? tr('فك الحظر') : tr('حظر')),
              onTap: () {
                Navigator.pop(context);
                _act(u, banned ? 'unblock' : 'block');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
              title: Text(tr('حذف الحساب والبطاقة'), style: const TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(context);
                _act(u, 'delete');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        margin: const EdgeInsetsDirectional.only(end: 6, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(text, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w700)),
      );

  Widget _stat(String label, int n) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text('$n', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted), textAlign: TextAlign.center),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final confirmed = users.where((u) => u['confirmed_at'] != null).length;
    final withCard = users.where((u) => '${u['slug'] ?? ''}'.isNotEmpty).length;
    final blocked = users.where((u) => u['banned'] == true).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('مسجّلو الموقع')),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded), tooltip: tr('تحديث'))],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => load(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: tr('ابحث بالبريد أو الاسم'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _stat(tr('مسجّل'), users.length),
              const SizedBox(width: 6),
              _stat(tr('مفعّل'), confirmed),
              const SizedBox(width: 6),
              _stat(tr('لديه بطاقة'), withCard),
              const SizedBox(width: 6),
              _stat(tr('محظور'), blocked),
            ]),
            const SizedBox(height: 10),
            if (loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              Padding(padding: const EdgeInsets.all(20), child: Text(error!, style: const TextStyle(color: AppColors.danger)))
            else if (users.isEmpty)
              Padding(padding: const EdgeInsets.all(30), child: Center(child: Text(tr('لا أحد سجّل في الموقع بعد.'))))
            else
              for (final u in users)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _openUser(u),
                    leading: CircleAvatar(
                      backgroundColor: (u['banned'] == true ? AppColors.danger : AppColors.primary).withValues(alpha: 0.18),
                      child: Text(('${u['email'] ?? '?'}').characters.first.toUpperCase()),
                    ),
                    title: Text('${u['title'] ?? u['email']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${u['email']}', textDirection: TextDirection.ltr, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(trf('سجّل {0} · {1} زيارة · {2} تعديل', [_date(u['created_at']), _int(u['scans']), _int(u['edits'])]),
                            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        Wrap(children: [
                          if (u['confirmed_at'] == null) _chip(tr('غير مفعّل'), AppColors.warning),
                          if (u['banned'] == true) _chip(tr('محظور'), AppColors.danger),
                          if ('${u['slug'] ?? ''}'.isEmpty) _chip(tr('بدون بطاقة'), AppColors.muted),
                          if ('${u['slug'] ?? ''}'.isNotEmpty && u['published'] != true && u['banned'] != true) _chip(tr('بطاقة مخفية'), AppColors.warning),
                        ]),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_left_rounded),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
