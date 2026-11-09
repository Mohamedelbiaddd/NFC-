import 'package:flutter/material.dart';
import '../core/i18n.dart';

import '../core/repository.dart';
import '../core/theme.dart';
import '../core/workers_service.dart';

/// Super-administrator view of one account: every card it created (with scan
/// counts), everything it did in the app, and a block / unblock switch.
class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({
    super.key,
    required this.service,
    required this.user,
    required this.canBan,
  });

  final WorkersService service;
  final Json user;
  final bool canBan;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

Map<String, String> get _actionNames => {
  'profile_created': tr('أنشأ بطاقة'),
  'profile_updated': tr('عدّل بطاقة'),
  'profile_deleted': tr('حذف بطاقة'),
  'business_created': tr('أنشأ نشاطاً تجارياً'),
  'worker_created': tr('أضاف عاملاً'),
  'worker_updated': tr('عدّل عاملاً'),
  'worker_password_reset': tr('غيّر كلمة مرور عامل'),
  'worker_disabled': tr('أوقف عاملاً'),
  'worker_deleted': tr('حذف عاملاً'),
  'card_written': tr('كتب بطاقة NFC'),
  'card_verified': tr('تحقق من بطاقة'),
  'card_locked': tr('قفل بطاقة'),
  'qr_saved': tr('حفظ رمز QR'),
  'login': tr('سجّل الدخول'),
  'user_joined': tr('أنشأ حسابه'),
  'user_banned': tr('حظر حساباً'),
  'user_unbanned': tr('فك حظر حساب'),
  'pin_set': tr('وضع رمز تعديل لبطاقة'),
  'pin_removed': tr('أزال رمز تعديل'),
  'owner_edited': tr('صاحب البطاقة عدّلها'),
  'link_written': tr('كتب رابطاً مباشراً على NFC'),
};

class _UserDetailScreenState extends State<UserDetailScreen> {
  Json detail = const {};
  bool loading = true, busy = false;
  String? error;
  late bool banned;

  @override
  void initState() {
    super.initState();
    banned = _isBanned(widget.user['banned_until']);
    load();
  }

  static bool _isBanned(dynamic until) {
    if (until is! String) return false;
    final time = DateTime.tryParse(until);
    return time != null && time.isAfter(DateTime.now());
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.service.userDetail('${widget.user['user_id']}');
      if (mounted) setState(() => detail = value);
    } catch (e) {
      if (mounted) setState(() => error = userError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggleBan() async {
    final email = '${widget.user['email'] ?? ''}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(banned ? tr('فك الحظر؟') : tr('حظر الحساب؟')),
        content: Text(
          banned
              ? trf('سيستطيع «{0}» تسجيل الدخول من جديد.', [email])
              : trf('لن يستطيع «{0}» تسجيل الدخول، وتبقى بياناته محفوظة.', [email]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('إلغاء')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: banned ? AppColors.success : AppColors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(banned ? tr('فك الحظر') : tr('حظر')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await widget.service.setUserBanned(
        userId: '${widget.user['user_id']}',
        banned: !banned,
      );
      if (mounted) setState(() => banned = !banned);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Json> _list(String key) {
    final raw = detail[key];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final email = '${widget.user['email'] ?? ''}';
    final profiles = _list('profiles');
    final activity = _list('activity');
    final workspaces = _list('workspaces');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          email,
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.sync_rounded)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!, style: const TextStyle(color: AppColors.danger)))
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (widget.user['is_admin'] == true)
                              Pill(tr('مدير عام'), color: AppColors.warning, icon: Icons.shield_rounded),
                            if (banned)
                              Pill(tr('محظور'), color: AppColors.danger, icon: Icons.block_rounded)
                            else
                              Pill(tr('نشط'), color: AppColors.success),
                            for (final w in workspaces)
                              Pill('${w['name']} · ${w['role']}'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _stat(tr('بطاقات أنشأها'), '${profiles.length}'),
                            _stat(tr('نشاطات'), '${activity.length}'),
                            _stat(
                              tr('مسح البطاقات'),
                              '${profiles.fold<int>(0, (s, p) => s + (int.tryParse('${p['scans']}') ?? 0))}',
                            ),
                          ],
                        ),
                        if (widget.canBan) ...[
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: busy ? null : toggleBan,
                            style: FilledButton.styleFrom(
                              backgroundColor: banned ? AppColors.success : AppColors.danger,
                            ),
                            icon: Icon(banned ? Icons.lock_open_rounded : Icons.block_rounded),
                            label: Text(banned ? tr('فك الحظر') : tr('حظر هذا الحساب')),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SectionTitle(tr('البطاقات التي أنشأها')),
                  if (profiles.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(tr('لم ينشئ أي بطاقة بعد.'), style: TextStyle(color: AppColors.muted)),
                    ),
                  for (final p in profiles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SurfaceCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              p['published'] == true ? Icons.public : Icons.public_off,
                              color: p['published'] == true ? AppColors.accent : AppColors.muted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${p['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    '/p/${p['slug']} · ${p['business']} · ${shortDate(DateTime.tryParse('${p['created_at']}'))}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Text('${p['scans']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(tr('مسح'), style: TextStyle(fontSize: 10, color: AppColors.muted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  SectionTitle(tr('كل ما فعله في التطبيق')),
                  if (activity.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(tr('لا نشاط مسجّل.'), style: TextStyle(color: AppColors.muted)),
                    ),
                  for (final a in activity)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_rounded, size: 20, color: AppColors.primarySoft),
                      title: Text(
                        [
                          _actionNames['${a['action']}'] ?? '${a['action']}',
                          if ('${a['subject'] ?? ''}'.isNotEmpty) '«${a['subject']}»',
                        ].join(' '),
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        '${relativeTime(DateTime.tryParse('${a['created_at']}'))} · ${a['workspace']}',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ],
    ),
  );
}
