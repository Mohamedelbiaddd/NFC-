import 'package:flutter/material.dart';
import '../core/i18n.dart';

import '../core/repository.dart';
import '../core/theme.dart';
import '../core/workers_service.dart';
import 'user_detail_screen.dart';

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
    return trf('{0}', [user['email'] ?? tr('حساب')]);
  }

  Future<void> _toggleBan(Json user) async {
    final id = '${user['user_id']}';
    final banned = _banned(user);
    final name = _name(user);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(banned ? tr('فك الحظر عن الحساب؟') : tr('حظر الحساب؟')),
        content: Text(
          banned
              ? trf('سيستطيع «{0}» تسجيل الدخول من جديد بمجرد فك الحظر.', [name])
              : trf('لن يستطيع «{0}» تسجيل الدخول بعد الآن، مع بقاء بياناته وسجلاته محفوظة لديك. يمكنك فك الحظر في أي وقت.', [name]),
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
    if (confirmed != true) return;
    setState(() => busyId = id);
    try {
      await widget.service.setUserBanned(userId: id, banned: !banned);
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(banned ? tr('تم فك الحظر.') : tr('تم حظر الحساب.')),
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
        title: tr('تعذّر تحميل المستخدمين'),
        text: error!,
        action: FilledButton.icon(
          onPressed: load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(tr('إعادة المحاولة')),
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
                    Expanded(
                      child: Text(
                        tr('لوحة المدير العام'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Pill(trf('{0} حساب', [users.length]), color: AppColors.accent),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _stat(tr('مستخدم'), '${users.length}', AppColors.accent),
                    _stat(tr('بطاقة'), '$totalProfiles', AppColors.success),
                    _stat(tr('مشاهدة'), '$totalScans', AppColors.primarySoft),
                    _stat(tr('كتابة NFC'), '$totalCards', AppColors.warning),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: search,
            onChanged: (_) => load(),
            decoration: InputDecoration(
              hintText: tr('ابحث ببريد المستخدم…'),
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: 18),
          if (users.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                tr('لا يوجد مستخدمون مطابقون.'),
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
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => UserDetailScreen(
                service: widget.service,
                user: user,
                canBan: !isMe && !isAdmin,
              ),
            ),
          );
          if (mounted) await load();
        },
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
                            Pill(
                              tr('مدير عام'),
                              color: AppColors.warning,
                              icon: Icons.shield_rounded,
                            ),
                          if (isMe) Pill(tr('أنت'), color: AppColors.accent),
                          if (banned)
                            Pill(
                              tr('محظور'),
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
                    tooltip: banned ? tr('فك الحظر') : tr('حظر'),
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
                _mini(tr('بطاقات'), '${_int(user['profiles_created'])}'),
                _mini('NFC', '${_int(user['cards_written'])}'),
                _mini(tr('مشاهدات'), '${_int(user['scans'])}'),
                _mini(tr('نشاطات'), '${_int(user['actions'])}'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              [
                if (signedUp != null) trf('سجّل {0}', [shortDate(signedUp)]),
                if (last != null)
                  trf('آخر نشاط {0}', [relativeTime(last)])
                else
                  tr('لا نشاط بعد'),
              ].join(' · '),
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                tr('اضغط لعرض التفاصيل ›'),
                style: TextStyle(fontSize: 11, color: AppColors.primarySoft),
              ),
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
