import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../core/network_service.dart';

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
  late final NetworkService network = NetworkService(widget.service.client);

  bool get _isAdmin => widget.user['is_admin'] == true;

  Future<bool> _confirm(String title, String body, {String? typeToConfirm, String action = 'حذف'}) async {
    final typed = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(body),
              if (typeToConfirm != null) ...[
                const SizedBox(height: 10),
                Text(tr('للتأكيد اكتب:'), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                SelectableText(typeToConfirm, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w800)),
                TextField(controller: typed, textDirection: TextDirection.ltr, onChanged: (_) => setLocal(() {})),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('إلغاء'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: typeToConfirm == null || typed.text.trim() == typeToConfirm.trim()
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text(tr(action)),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _run(Future<void> Function() job, String done) async {
    setState(() => busy = true);
    try {
      await job();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _deleteShop(Json shop) async {
    final customers = (shop['customers'] as num?)?.toInt() ?? 0;
    if (!await _confirm(
      trf('حذف المحل «{0}»؟', [shop['name']]),
      trf('سيُحذف المحل نهائياً مع {0} زبون ونقاطهم وحجوزاتهم وبطاقته. لا يمكن التراجع.', [customers]),
    )) return;
    await _run(() => network.deleteShop('${shop['id']}'), tr('تم حذف المحل.'));
  }

  Future<void> _deleteProfile(Json p) async {
    if (!await _confirm(trf('حذف البطاقة «{0}»؟', [p['title']]), tr('ستُحذف البطاقة ورابطها نهائياً.'))) return;
    await _run(() => network.deleteProfile('${p['id']}'), tr('تم حذف البطاقة.'));
  }

  Future<void> _deleteAllProfiles(int count) async {
    if (!await _confirm(trf('حذف كل البطاقات ({0})؟', [count]), tr('ستُحذف كل البطاقات التي أنشأها هذا الحساب نهائياً. المحلات تبقى.'))) return;
    await _run(() async => await network.deleteProfilesOf('${widget.user['user_id']}'), tr('تم حذف البطاقات.'));
  }

  Future<void> _purge(bool hasTeam) async {
    final email = '${widget.user['email'] ?? ''}';
    var withTeam = false;
    if (hasTeam) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('لهذا الحساب أشخاص تابعون له')),
          content: Text(tr('هل تحذف فريقه أيضاً مع كل ما أنشؤوه؟ إن اخترت «أبقِهم» ينتقلون إلى المسؤول الذي فوقه.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('أبقِهم'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('احذف الفريق أيضاً')),
            ),
          ],
        ),
      );
      if (choice == null) return;
      withTeam = choice;
    }
    if (!mounted) return;
    if (!await _confirm(
      tr('حذف الحساب نهائياً؟'),
      tr('سيُحذف الحساب ولن يستطيع الدخول للتطبيق، وتُحذف معه محلاته وزبائنها وبطاقاته ومساحات عمله. لا يمكن التراجع.'),
      typeToConfirm: email,
    )) return;
    setState(() => busy = true);
    try {
      await network.purge('${widget.user['user_id']}', withTeam: withTeam);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تم حذف الحساب وكل ما أنشأه.'))));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

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
    final shops = _list('shops');
    final members = _list('members');
    final staff = detail['staff'] is Map ? Map<String, dynamic>.from(detail['staff'] as Map) : null;
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
                  if (staff != null && staff['role'] == 'agent' && widget.canBan) ...[
                    const SizedBox(height: 18),
                    SectionTitle(tr('صلاحياته')),
                    SurfaceCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: staff['can_add_members'] != false,
                            title: Text(tr('يستطيع إضافة أشخاص تابعين له')),
                            onChanged: busy ? null : (v) => _run(
                              () => network.setPermissions('${widget.user['user_id']}', canAdd: v),
                              tr('تم الحفظ.'),
                            ),
                          ),
                          SwitchListTile(
                            value: staff['can_manage_members'] != false,
                            title: Text(tr('يستطيع إدارة فريقه (كلمات المرور، الإيقاف، الحذف)')),
                            onChanged: busy ? null : (v) => _run(
                              () => network.setPermissions('${widget.user['user_id']}', canManage: v),
                              tr('تم الحفظ.'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (members.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    SectionTitle(trf('الأشخاص الذين أضافهم ({0})', [members.length])),
                    for (final m in members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(m['active'] == false ? Icons.person_off_rounded : Icons.person_rounded,
                            color: m['active'] == false ? AppColors.danger : AppColors.primarySoft),
                        title: Text('${m['name']}'),
                        subtitle: Text('${m['email']}', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => UserDetailScreen(
                                service: widget.service,
                                user: {'user_id': m['user_id'], 'email': m['email']},
                                canBan: widget.canBan,
                              ),
                            ),
                          );
                          if (mounted) load();
                        },
                      ),
                  ],
                  const SizedBox(height: 18),
                  SectionTitle(trf('المحلات التي أنشأها ({0})', [shops.length])),
                  if (shops.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(tr('لا محلات.'), style: const TextStyle(color: AppColors.muted)),
                    ),
                  for (final shop in shops)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SurfaceCard(
                        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_rounded, color: AppColors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${shop['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    '/c/${shop['slug']} · ${trf('{0} زبون', [shop['customers']])}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: tr('حذف'),
                              onPressed: busy ? null : () => _deleteShop(shop),
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: SectionTitle(tr('البطاقات التي أنشأها'))),
                      if (profiles.isNotEmpty)
                        TextButton.icon(
                          onPressed: busy ? null : () => _deleteAllProfiles(profiles.length),
                          icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.danger, size: 18),
                          label: Text(tr('حذف الكل'), style: const TextStyle(color: AppColors.danger)),
                        ),
                    ],
                  ),
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
                            IconButton(
                              tooltip: tr('حذف'),
                              onPressed: busy ? null : () => _deleteProfile(p),
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (widget.canBan && !_isAdmin) ...[
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: busy ? null : () => _purge(members.isNotEmpty),
                      icon: const Icon(Icons.person_remove_rounded),
                      label: Text(tr('حذف الحساب نهائياً مع كل ما أنشأه')),
                    ),
                  ],
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
