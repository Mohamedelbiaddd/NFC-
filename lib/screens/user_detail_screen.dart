import 'package:flutter/material.dart';

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

const _actionNames = {
  'profile_created': 'أنشأ بطاقة',
  'profile_updated': 'عدّل بطاقة',
  'profile_deleted': 'حذف بطاقة',
  'business_created': 'أنشأ نشاطاً تجارياً',
  'worker_created': 'أضاف عاملاً',
  'worker_updated': 'عدّل عاملاً',
  'worker_password_reset': 'غيّر كلمة مرور عامل',
  'worker_disabled': 'أوقف عاملاً',
  'worker_deleted': 'حذف عاملاً',
  'card_written': 'كتب بطاقة NFC',
  'card_verified': 'تحقق من بطاقة',
  'card_locked': 'قفل بطاقة',
  'qr_saved': 'حفظ رمز QR',
  'login': 'سجّل الدخول',
  'user_joined': 'أنشأ حسابه',
  'user_banned': 'حظر حساباً',
  'user_unbanned': 'فك حظر حساب',
  'pin_set': 'وضع رمز تعديل لبطاقة',
  'pin_removed': 'أزال رمز تعديل',
  'owner_edited': 'صاحب البطاقة عدّلها',
  'link_written': 'كتب رابطاً مباشراً على NFC',
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
        title: Text(banned ? 'فك الحظر؟' : 'حظر الحساب؟'),
        content: Text(
          banned
              ? 'سيستطيع «$email» تسجيل الدخول من جديد.'
              : 'لن يستطيع «$email» تسجيل الدخول، وتبقى بياناته محفوظة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: banned ? AppColors.success : AppColors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(banned ? 'فك الحظر' : 'حظر'),
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
                              const Pill('مدير عام', color: AppColors.warning, icon: Icons.shield_rounded),
                            if (banned)
                              const Pill('محظور', color: AppColors.danger, icon: Icons.block_rounded)
                            else
                              const Pill('نشط', color: AppColors.success),
                            for (final w in workspaces)
                              Pill('${w['name']} · ${w['role']}'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _stat('بطاقات أنشأها', '${profiles.length}'),
                            _stat('نشاطات', '${activity.length}'),
                            _stat(
                              'مسح البطاقات',
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
                            label: Text(banned ? 'فك الحظر' : 'حظر هذا الحساب'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SectionTitle('البطاقات التي أنشأها'),
                  if (profiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('لم ينشئ أي بطاقة بعد.', style: TextStyle(color: AppColors.muted)),
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
                                const Text('مسح', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  const SectionTitle('كل ما فعله في التطبيق'),
                  if (activity.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('لا نشاط مسجّل.', style: TextStyle(color: AppColors.muted)),
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
