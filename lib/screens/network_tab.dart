import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/network_service.dart';
import '../core/repository.dart';
import '../core/theme.dart';

Color statusColor(String? status) => switch (status) {
  'paid' => AppColors.success,
  'expired' => AppColors.danger,
  _ => AppColors.muted,
};

const noticeTemplates = <String, String>{
  'العربية':
      'تذكير ودّي 🌟\nلاحظنا أن اشتراك هذا الشهر لم يُدفع بعد. هذا الاشتراك يغطي تكاليف الخادم '
      'وتشغيل بطاقات الولاء لزبائنك.\nالمرجو تسوية المبلغ في أقرب وقت لتستمر الخدمة دون انقطاع، '
      'وإلا سيتم إيقاف الحساب مؤقتاً.\nشكراً لثقتك 🙏',
  'Français':
      'Petit rappel 🌟\nL’abonnement de ce mois n’a pas encore été réglé. Il couvre les frais du serveur '
      'et le fonctionnement de la carte de fidélité de vos clients.\nMerci de régler le montant rapidement '
      'pour éviter une suspension temporaire du compte.\nMerci de votre confiance 🙏',
  'English':
      'Friendly reminder 🌟\nThis month’s subscription has not been paid yet. It covers the server costs '
      'and keeps your customers’ loyalty card running.\nPlease settle the amount soon to avoid a temporary '
      'suspension of the account.\nThank you for your trust 🙏',
};

/// Lets an agent / admin write (or remove) the payment notice shown to a shop
/// owner or staff member. Returns true when something changed.
Future<bool> editNotice(
  BuildContext context,
  NetworkService service,
  String subject,
  String id,
  String name,
  String? current,
) async {
  final text = TextEditingController(text: current ?? noticeTemplates['العربية']);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('تنبيه دفع إلى «$name»'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              children: [
                for (final entry in noticeTemplates.entries)
                  ActionChip(label: Text(entry.key), onPressed: () => text.text = entry.value),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: text, minLines: 5, maxLines: 9, maxLength: 1000),
            Text(
              subject == 'shop'
                  ? 'يظهر في أعلى لوحة صاحب المحل. لا يوقف أي شيء، والإيقاف يبقى بقرارك.'
                  : 'يظهر للعامل داخل التطبيق. لا يوقف أي شيء، والإيقاف يبقى بقرارك.',
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
      actions: [
        if (current != null)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('إزالة التنبيه', style: TextStyle(color: AppColors.danger)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(context, text.text.trim()), child: const Text('إرسال')),
      ],
    ),
  );
  text.dispose();
  if (result == null) return false;
  await service.setNotice(subject, id, result);
  return true;
}

/// The caller's staff network: agents and workers below them, their monthly
/// subscription (green / red), suspension and password resets, plus a live
/// feed of everything that happened in the network.
class NetworkTab extends StatefulWidget {
  const NetworkTab({super.key, required this.service, required this.isSuper});

  final NetworkService service;
  final bool isSuper;

  @override
  State<NetworkTab> createState() => _NetworkTabState();
}

class _NetworkTabState extends State<NetworkTab> {
  List<Json> members = const [];
  List<Json> events = const [];
  bool loading = true, showEvents = false;
  String? error;
  String filter = 'all';
  Timer? timer;

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => load(quiet: true));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load({bool quiet = false}) async {
    if (!quiet) setState(() => loading = true);
    try {
      final results = await Future.wait([widget.service.members(), widget.service.events(max: 150)]);
      if (!mounted) return;
      setState(() {
        members = results[0];
        events = results[1];
        error = null;
      });
    } catch (e) {
      if (mounted && !quiet) setState(() => error = userError(e));
    } finally {
      if (mounted && !quiet) setState(() => loading = false);
    }
  }

  void _snack(String text, {bool bad = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: bad ? AppColors.danger : AppColors.success),
    );
  }

  Future<void> _guard(Future<void> Function() action, String done) async {
    try {
      await action();
      await load(quiet: true);
      _snack(done);
    } catch (e) {
      _snack(e is NetworkException ? e.message : userError(e), bad: true);
    }
  }

  Future<void> _showPassword(String name, String email, String password) async {
    final message =
        'مرحباً $name 👋\nحسابك في NFC Studio جاهز.\nالبريد: $email\nكلمة المرور: $password\n\n'
        'نزّل التطبيق وسجّل الدخول بهذه البيانات.';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ بيانات الدخول'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(email, textDirection: TextDirection.ltr),
            const SizedBox(height: 8),
            SelectableText(
              password,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            const Text(
              'أرسلها الآن: كلمة المرور لا تُعرض مرة أخرى (يمكن إنشاء واحدة جديدة).',
              style: TextStyle(fontSize: 11.5, color: AppColors.warning),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: message)),
            child: const Text('نسخ'),
          ),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('واتساب'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم')),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final name = TextEditingController(), email = TextEditingController();
    var role = widget.isSuper ? 'agent' : 'worker';
    var busy = false;
    String? err;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('إضافة حساب جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isSuper)
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'agent', label: Text('وكيل'), icon: Icon(Icons.hub_outlined)),
                    ButtonSegment(value: 'worker', label: Text('عامل'), icon: Icon(Icons.person_outline)),
                  ],
                  selected: {role},
                  onSelectionChanged: (v) => setLocal(() => role = v.first),
                ),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
              const SizedBox(height: 10),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              ),
              const SizedBox(height: 8),
              Text(
                role == 'agent'
                    ? 'الوكيل يستطيع إضافة عماله ومتابعتهم، ولا يرى إلا شبكته.'
                    : 'العامل يسجّل المحلات ويرى محلاته فقط.',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setLocal(() {
                        busy = true;
                        err = null;
                      });
                      try {
                        final pass = await widget.service.create(
                          email: email.text.trim(),
                          name: name.text.trim(),
                          role: role,
                        );
                        if (context.mounted) Navigator.pop(context);
                        await load(quiet: true);
                        await _showPassword(name.text.trim(), email.text.trim().toLowerCase(), pass);
                      } catch (e) {
                        setLocal(() {
                          busy = false;
                          err = e is NetworkException ? e.message : userError(e);
                        });
                      }
                    },
              child: Text(busy ? 'جارٍ الإنشاء…' : 'إنشاء وتوليد كلمة مرور'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    email.dispose();
  }

  Future<void> _togglePaid(Json m) async {
    final id = '${m['user_id']}';
    if (m['status'] == 'paid') {
      final ok = await _confirm('إلغاء آخر دفعة؟', 'سيرجع تاريخ الاشتراك كما كان قبل آخر علامة ✓.');
      if (ok) await _guard(() => widget.service.undoPayment('staff', id), 'تم إلغاء الدفعة');
    } else {
      await _guard(() => widget.service.markPaid('staff', id), '✓ تم تسجيل دفع شهر');
    }
  }

  Future<bool> _confirm(String title, String text, {String yes = 'تأكيد'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(yes)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _suspend(Json m) async {
    final id = '${m['user_id']}';
    final active = m['active'] == true;
    if (!active) {
      await _guard(() => widget.service.setStaffActive(id, true, includeShops: true), 'تم تفعيل الحساب ومحلاته');
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إيقاف «${m['name']}»؟'),
        content: const Text('لن يستطيع تسجيل الدخول. يمكنك أيضاً إيقاف كل المحلات التي سجّلها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, 'login'), child: const Text('الحساب فقط')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, 'all'),
            child: const Text('الحساب ومحلاته'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    await _guard(
      () => widget.service.setStaffActive(id, false, includeShops: choice == 'all'),
      'تم الإيقاف',
    );
  }

  Future<void> _notice(Json m) async {
    try {
      final changed = await editNotice(context, widget.service, 'staff', '${m['user_id']}', '${m['name']}', m['notice'] as String?);
      if (changed) {
        await load(quiet: true);
        _snack('تم');
      }
    } catch (e) {
      _snack(userError(e), bad: true);
    }
  }

  Future<void> _reset(Json m) async {
    final ok = await _confirm('كلمة مرور جديدة؟', 'ستتوقف كلمة المرور القديمة فوراً.', yes: 'إنشاء');
    if (!ok) return;
    try {
      final pass = await widget.service.resetPassword('${m['user_id']}');
      await _showPassword('${m['name']}', '${m['email']}', pass);
    } catch (e) {
      _snack(e is NetworkException ? e.message : userError(e), bad: true);
    }
  }

  Future<void> _delete(Json m) async {
    final ok = await _confirm('حذف «${m['name']}» نهائياً؟', 'لا يمكن التراجع. الحسابات التي لها محلات أو عمال تُوقف ولا تُحذف.', yes: 'حذف');
    if (!ok) return;
    try {
      await widget.service.delete('${m['user_id']}');
      await load(quiet: true);
      _snack('تم الحذف');
    } catch (e) {
      _snack(e is NetworkException ? e.message : userError(e), bad: true);
    }
  }

  // Depth in the visible tree (0 = directly under the viewer).
  int _depth(Json m, Map<String, Json> byId) {
    var depth = 0;
    var parent = '${m['parent_id']}';
    while (byId.containsKey(parent) && depth < 10) {
      depth++;
      parent = '${byId[parent]!['parent_id']}';
    }
    return depth;
  }

  List<Json> _ordered() {
    final byId = {for (final m in members) '${m['user_id']}': m};
    final children = <String, List<Json>>{};
    final roots = <Json>[];
    for (final m in members) {
      final p = '${m['parent_id']}';
      if (byId.containsKey(p)) {
        children.putIfAbsent(p, () => []).add(m);
      } else {
        roots.add(m);
      }
    }
    final out = <Json>[];
    void walk(Json m) {
      out.add(m);
      for (final c in children['${m['user_id']}'] ?? const <Json>[]) {
        walk(c);
      }
    }
    for (final r in roots) {
      walk(r);
    }
    return out.where((m) => filter == 'all' || m['status'] == filter || (filter == 'expired' && m['status'] == 'never')).toList();
  }

  Widget _memberCard(Json m, int depth) {
    final status = '${m['status']}';
    final color = statusColor(status);
    final active = m['active'] == true;
    final paidUntil = DateTime.tryParse('${m['paid_until'] ?? ''}');
    return Padding(
      padding: EdgeInsetsDirectional.only(start: depth * 18.0, bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1.4),
        ),
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Checkbox(
                  value: status == 'paid',
                  activeColor: AppColors.success,
                  onChanged: (_) => _togglePaid(m),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${m['name']}',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color == AppColors.muted ? null : color),
                      ),
                      Text('${m['email']}', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'pay3':
                        _guard(() => widget.service.markPaid('staff', '${m['user_id']}', months: 3), '✓ تم تسجيل 3 أشهر');
                      case 'notice':
                        _notice(m);
                      case 'reset':
                        _reset(m);
                      case 'suspend':
                        _suspend(m);
                      case 'delete':
                        _delete(m);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'pay3', child: Text('💵 دفع 3 أشهر')),
                    PopupMenuItem(value: 'notice', child: Text(m['notice'] == null ? '📩 إرسال تنبيه دفع' : '📩 تعديل / إزالة التنبيه')),
                    const PopupMenuItem(value: 'reset', child: Text('🔑 كلمة مرور جديدة')),
                    PopupMenuItem(value: 'suspend', child: Text(active ? '⛔ إيقاف' : '✅ تفعيل')),
                    const PopupMenuItem(value: 'delete', child: Text('🗑️ حذف')),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Pill(m['role'] == 'agent' ? 'وكيل' : 'عامل', icon: m['role'] == 'agent' ? Icons.hub_outlined : Icons.person_outline),
                  Pill(
                    status == 'paid' && paidUntil != null
                        ? 'مدفوع حتى ${shortDate(paidUntil)}'
                        : status == 'expired' && paidUntil != null
                        ? 'انتهى ${shortDate(paidUntil)}'
                        : statusLabel(status),
                    color: color,
                  ),
                  Pill('${m['shops']} محل', color: AppColors.accent, icon: Icons.storefront_outlined),
                  if ((m['members'] as num? ?? 0) > 0) Pill('${m['members']} عامل', color: AppColors.accent),
                  if (!active) const Pill('موقوف', color: AppColors.danger, icon: Icons.block),
                  if (m['notice'] != null) const Pill('📩 تنبيه مُرسل', color: AppColors.warning),
                  if (widget.isSuper && '${m['parent_name'] ?? ''}'.isNotEmpty) Pill('تابع لـ ${m['parent_name']}', color: AppColors.muted),
                  Pill('آخر دخول: ${relativeTime(DateTime.tryParse('${m['last_sign_in'] ?? ''}'))}', color: AppColors.muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _eventNames = {
    'staff_created': 'أضاف حساباً',
    'staff_suspended': 'أوقف حساب',
    'staff_resumed': 'فعّل حساب',
    'staff_deleted': 'حذف حساب',
    'password_reset': 'غيّر كلمة مرور',
    'payment': '✓ سجّل دفع',
    'payment_undone': 'ألغى دفعة',
    'shop_created': 'سجّل محلاً',
    'shop_suspended': 'أوقف محل',
    'shop_resumed': 'فعّل محل',
    'notice_sent': '📩 أرسل تنبيه دفع إلى',
    'notice_cleared': 'أزال التنبيه عن',
  };

  Widget _eventsList() => Column(
    children: [
      if (events.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('لا توجد حركات بعد.', style: TextStyle(color: AppColors.muted)),
        ),
      for (final e in events)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            '${e['action']}'.startsWith('payment') ? Icons.payments_outlined : '${e['subject_type']}' == 'shop' ? Icons.storefront_outlined : Icons.person_outline,
            color: '${e['action']}' == 'payment' ? AppColors.success : '${e['action']}'.contains('suspend') ? AppColors.danger : AppColors.primarySoft,
            size: 20,
          ),
          title: Text('${e['actor']} ${_eventNames['${e['action']}'] ?? e['action']} «${e['subject_name'] ?? ''}»', style: const TextStyle(fontSize: 13)),
          subtitle: Text(relativeTime(DateTime.tryParse('${e['created_at']}')), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final byId = {for (final m in members) '${m['user_id']}': m};
    final paid = members.where((m) => m['status'] == 'paid').length;
    final unpaid = members.length - paid;
    final list = _ordered();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-staff',
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(widget.isSuper ? 'وكيل / عامل جديد' : 'عامل جديد'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
                children: [
                  Row(
                    children: [
                      Expanded(child: _summary('${members.length}', 'في شبكتك', AppColors.primarySoft, 'all')),
                      const SizedBox(width: 8),
                      Expanded(child: _summary('$paid', 'مدفوع', AppColors.success, 'paid')),
                      const SizedBox(width: 8),
                      Expanded(child: _summary('$unpaid', 'غير مدفوع', AppColors.danger, 'expired')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('الأعضاء'), icon: Icon(Icons.groups_outlined)),
                      ButtonSegment(value: true, label: Text('الحركات'), icon: Icon(Icons.timeline)),
                    ],
                    selected: {showEvents},
                    onSelectionChanged: (v) => setState(() => showEvents = v.first),
                  ),
                  const SizedBox(height: 12),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(error!, style: const TextStyle(color: AppColors.danger)),
                    ),
                  if (showEvents)
                    _eventsList()
                  else ...[
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Text(
                          'لا يوجد أعضاء بعد.\nاضغط الزر بالأسفل لإضافة أول حساب بالبريد الإلكتروني.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted, height: 1.8),
                        ),
                      ),
                    for (final m in list) _memberCard(m, _depth(m, byId)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _summary(String value, String label, Color color, String key) => InkWell(
    onTap: () => setState(() {
      filter = key;
      showEvents = false;
    }),
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filter == key ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ],
      ),
    ),
  );
}
