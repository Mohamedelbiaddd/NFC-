import 'package:flutter/material.dart';

import '../core/repository.dart';
import '../core/theme.dart';
import '../core/workers_service.dart';

/// Super-administrator only: every account in the project, what it produced,
/// and the power to block it instantly.
class UsersTab extends StatefulWidget {
  const UsersTab({
    super.key,
    required this.service,
    required this.currentUserId,
  });

  final WorkersService service;
  final String? currentUserId;

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  final search = TextEditingController();
  List<Json> users = const [];
  bool loading = true;
  String? error;
  String? busyId;

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
      final rows = await widget.service.allUsers(term: search.text.trim());
      if (!mounted) return;
      setState(() => users = rows);
    } catch (e) {
      if (mounted) setState(() => error = userError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  int get totalScans => users.fold<int>(
    0,
    (sum, u) => sum + _int(u['scans']),
  );
  int get totalProfiles => users.fold<int>(
    0,
    (sum, u) => sum + _int(u['profiles_created']),
  );
  int get totalCards => users.fold<int>(
    0,
    (sum, u) => sum + _int(u['cards_written']),
  );

  static int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;

  bool _banned(Json user) {
    final until = user['banned_until'];
    if (until is! String) return false;
    final time = DateTime.tryParse(until);
    return time != null && time.isAfter(DateTime.now());
  }

  String _name(Json user) {
    final display = '${user['display_name'] ?? ''}'.trim();
    if (display.isNotEmpty) return display;
    return '${user['email'] ?? 'حساب'}';
  }

  Future<void> _toggleBan(Json user) async {
    final id = '${user['user_id']}';
    final banned = _banned(user);
    final name = _name(user);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(banned ? 'فك الحظر عن الحساب؟' : 'حظر الحساب؟'),
        content: Text(
          banned
              ? 'سيستطيع «$name» تسجيل الدخول من جديد بمجرد فك الحظر.'
              : 'لن يستطيع «$name» تسجيل الدخول بعد الآن، مع بقاء بياناته '
                    'وسجلاته محفوظة لديك. يمكنك فك الحظر في أي وقت.',
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
    if (confirmed != true) return;
    setState(() => busyId = id);
    try {
      await widget.service.setUserBanned(userId: id, banned: !banned);
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(banned ? 'تم فك الحظر.' : 'تم حظر الحساب.'),
        ),
      );
    } on WorkerException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return EmptyState(
        icon: Icons.shield_outlined,
        title: 'تعذّر تحميل المستخدمين',
        text: error!,
        action: FilledButton.icon(
          onPressed: load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'لوحة المدير العام',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Pill('${users.length} حساب', color: AppColors.accent),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _stat('مستخدم', '${users.length}', AppColors.accent),
                    _stat('بطاقة', '$totalProfiles', AppColors.success),
                    _stat('مشاهدة', '$totalScans', AppColors.primarySoft),
                    _stat('كتابة NFC', '$totalCards', AppColors.warning),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: search,
            onChanged: (_) => load(),
            decoration: const InputDecoration(
              hintText: 'ابحث ببريد المستخدم…',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: 18),
          if (users.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'لا يوجد مستخدمون مطابقون.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            ...users.map(_userCard),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    ),
  );

  Widget _userCard(Json user) {
    final email = '${user['email'] ?? ''}';
    final isAdmin = user['is_admin'] == true;
    final banned = _banned(user);
    final isMe = user['user_id'] == widget.currentUserId;
    final last = user['last_active'] is String
        ? DateTime.tryParse('${user['last_active']}')
        : null;
    final signedUp = user['signed_up'] is String
        ? DateTime.tryParse('${user['signed_up']}')
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isAdmin ? AppColors.warning : AppColors.primarySoft)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isAdmin
                        ? Icons.shield_rounded
                        : Icons.person_outline_rounded,
                    color: isAdmin ? AppColors.warning : AppColors.primarySoft,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (isAdmin)
                            const Pill(
                              'مدير عام',
                              color: AppColors.warning,
                              icon: Icons.shield_rounded,
                            ),
                          if (isMe) const Pill('أنت', color: AppColors.accent),
                          if (banned)
                            const Pill(
                              'محظور',
                              color: AppColors.danger,
                              icon: Icons.block_rounded,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isMe && !isAdmin)
                  IconButton(
                    tooltip: banned ? 'فك الحظر' : 'حظر',
                    onPressed: busyId == null ? () => _toggleBan(user) : null,
                    icon: busyId == '${user['user_id']}'
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            banned
                                ? Icons.lock_open_rounded
                                : Icons.block_rounded,
                            color: banned
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _mini('بطاقات', '${_int(user['profiles_created'])}'),
                _mini('NFC', '${_int(user['cards_written'])}'),
                _mini('مشاهدات', '${_int(user['scans'])}'),
                _mini('نشاطات', '${_int(user['actions'])}'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              [
                if (signedUp != null) 'سجّل ${shortDate(signedUp)}',
                if (last != null)
                  'آخر نشاط ${relativeTime(last)}'
                else
                  'لا نشاط بعد',
              ].join(' · '),
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
        ),
      ],
    ),
  );
}
