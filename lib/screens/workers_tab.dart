import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/labels.dart';
import '../core/repository.dart';
import '../core/theme.dart';
import '../core/workers_service.dart';

/// Admin-only screen: mint field-worker logins and control their state.
class WorkersTab extends StatefulWidget {
  const WorkersTab({
    super.key,
    required this.service,
    required this.repo,
    required this.tenant,
    this.onChanged,
  });

  final WorkersService service;
  final Repository repo;
  final String tenant;
  final VoidCallback? onChanged;

  @override
  State<WorkersTab> createState() => _WorkersTabState();
}

class _WorkersTabState extends State<WorkersTab> {
  List<Json> members = const [];
  Map<String, Json> meta = const {};
  bool loading = true;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant WorkersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenant != widget.tenant) load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        widget.service.overview(widget.tenant),
        widget.repo.rows('nfc_workers', tenant: widget.tenant),
      ]);
      if (!mounted) return;
      setState(() {
        members = results[0];
        meta = {
          for (final row in results[1]) '${row['id']}': row,
        };
      });
    } catch (e) {
      if (mounted) setState(() => error = userError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Json> get workers =>
      members.where((m) => meta.containsKey('${m['user_id']}')).toList();

  String _display(Json member) {
    final name = '${member['display_name'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
    return '${member['username'] ?? ''}';
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.surfaceHigh,
      ),
    );
  }

  Future<void> _create() async {
    final draft = await showDialog<_WorkerDraft>(
      context: context,
      builder: (_) => const _NewWorkerDialog(),
    );
    if (draft == null) return;
    setState(() => busy = true);
    try {
      await widget.service.createWorker(
        tenant: widget.tenant,
        username: draft.username,
        displayName: draft.displayName,
        password: draft.password,
        role: draft.role,
      );
      await load();
      widget.onChanged?.call();
      _showCredentials(draft.username, draft.password);
    } on WorkerException catch (e) {
      _snack(e.message, error: true);
    } catch (e) {
      _snack(userError(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resetPassword(Json member) async {
    final controller = TextEditingController(text: _suggestPassword());
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('كلمة مرور جديدة · ${_display(member)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الجديدة',
                helperText: '8 أحرف على الأقل. يستخدمها العامل فوراً.',
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => controller.text = _suggestPassword(),
              icon: const Icon(Icons.casino_outlined, size: 18),
              label: const Text('اقتراح كلمة مرور'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (password == null || password.length < 8) return;
    setState(() => busy = true);
    try {
      await widget.service.resetPassword(
        tenant: widget.tenant,
        workerId: '${member['user_id']}',
        password: password,
      );
      widget.onChanged?.call();
      _showCredentials('${member['username'] ?? ''}', password);
    } on WorkerException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _toggleDisabled(Json member) async {
    final row = meta['${member['user_id']}'];
    final disabled = row?['disabled'] == true;
    setState(() => busy = true);
    try {
      await widget.service.setDisabled(
        tenant: widget.tenant,
        workerId: '${member['user_id']}',
        disabled: !disabled,
      );
      await load();
      widget.onChanged?.call();
      _snack(disabled ? 'تم تفعيل الحساب.' : 'تم تعطيل الحساب.');
    } on WorkerException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete(Json member) async {
    final name = _display(member);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف حساب العامل؟'),
        content: Text(
          'سيتم حذف حساب «$name» نهائياً. ستبقى نشاطاته السابقة محفوظة في السجل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      await widget.service.deleteWorker(
        tenant: widget.tenant,
        workerId: '${member['user_id']}',
      );
      await load();
      widget.onChanged?.call();
      _snack('تم حذف الحساب.');
    } on WorkerException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _suggestPassword() {
    const letters = 'abcdefghjkmnpqrstuvwxyz';
    const digits = '23456789';
    final random = Random.secure();
    final word = List.generate(
      6,
      (_) => letters[random.nextInt(letters.length)],
    ).join();
    final code = List.generate(
      3,
      (_) => digits[random.nextInt(digits.length)],
    ).join();
    return '$word$code';
  }

  void _showCredentials(String username, String password) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بيانات دخول العامل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'سلّم هذه البيانات للعامل. يدخل من شاشة الدخول إلى «اسم المستخدم» '
              'دون بريد إلكتروني.',
              style: TextStyle(height: 1.6),
            ),
            const SizedBox(height: 16),
            _credentialRow('اسم المستخدم', username),
            const SizedBox(height: 10),
            _credentialRow('كلمة المرور', password),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text: 'اسم المستخدم: $username\nكلمة المرور: $password',
                ),
              );
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('نسخ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  Widget _credentialRow(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const Spacer(),
        SelectableText(
          value,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 0.6,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (loading && members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'تعذّر تحميل الفريق',
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      color: AppColors.primarySoft,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'حسابات الميدان',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Pill('${workers.length} عامل', color: AppColors.accent),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'أنشئ اسم مستخدم وكلمة مرور لكل عامل. يسجّل العامل الدخول '
                  'باسم المستخدم، وتظهر كل أعماله في شاشة المتابعة.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: busy ? null : _create,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('إضافة عامل جديد'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('العاملون'),
          if (workers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'لا يوجد عمال بعد. أضف أول حساب لبدء المتابعة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            ...workers.map(_workerCard),
        ],
      ),
    );
  }

  Widget _workerCard(Json member) {
    final row = meta['${member['user_id']}'];
    final username = '${member['username'] ?? ''}';
    final role = '${member['role'] ?? 'editor'}';
    final disabled = row?['disabled'] == true;
    final last = member['last_active'];
    final lastTime = last is String ? DateTime.tryParse(last) : null;
    final name = _display(member);
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
                    color: (disabled ? AppColors.muted : AppColors.accent)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    disabled
                        ? Icons.person_off_outlined
                        : Icons.person_outline_rounded,
                    color: disabled ? AppColors.muted : AppColors.accent,
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
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (disabled) ...[
                            const SizedBox(width: 6),
                            const Pill('معطّل', color: AppColors.danger),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '@$username · ${roleLabel(role)} · أضاف '
                        '${member['profiles_created'] ?? 0} · كتب '
                        '${member['cards_written'] ?? 0}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !busy,
                  tooltip: 'خيارات',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.muted,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'password':
                        _resetPassword(member);
                      case 'toggle':
                        _toggleDisabled(member);
                      case 'delete':
                        _delete(member);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'password',
                      child: Text('إعادة تعيين كلمة المرور'),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(disabled ? 'تفعيل الحساب' : 'تعطيل الحساب'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'حذف الحساب',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 5),
                Text(
                  lastTime == null
                      ? 'لم يسجّل الدخول بعد'
                      : 'آخر نشاط ${relativeTime(lastTime)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerDraft {
  const _WorkerDraft({
    required this.username,
    required this.displayName,
    required this.password,
    required this.role,
  });

  final String username;
  final String displayName;
  final String password;
  final String role;
}

class _NewWorkerDialog extends StatefulWidget {
  const _NewWorkerDialog();

  @override
  State<_NewWorkerDialog> createState() => _NewWorkerDialogState();
}

class _NewWorkerDialogState extends State<_NewWorkerDialog> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController();
  final displayName = TextEditingController();
  final password = TextEditingController(text: _suggest());
  String role = 'editor';

  static String _suggest() {
    const letters = 'abcdefghjkmnpqrstuvwxyz';
    const digits = '23456789';
    final random = Random.secure();
    return '${List.generate(6, (_) => letters[random.nextInt(letters.length)]).join()}'
        '${List.generate(3, (_) => digits[random.nextInt(digits.length)]).join()}';
  }

  @override
  void dispose() {
    username.dispose();
    displayName.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('عامل ميداني جديد'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: displayName,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                    (v?.trim().length ?? 0) >= 2 ? null : 'الاسم مطلوب',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: username,
                textDirection: TextDirection.ltr,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_.-]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم',
                  prefixIcon: Icon(Icons.alternate_email),
                  helperText: 'حروف لاتينية صغيرة وأرقام، 3 أحرف على الأقل',
                ),
                validator: (v) => RegExp(
                  r'^[a-z0-9][a-z0-9_.-]{2,31}$',
                ).hasMatch(v?.trim().toLowerCase() ?? '')
                    ? null
                    : 'اسم مستخدم غير صالح',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: password,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: Icon(Icons.key_rounded),
                  helperText: '8 أحرف على الأقل — يمكنك تعديلها',
                ),
                validator: (v) =>
                    (v?.length ?? 0) >= 8 ? null : '8 أحرف على الأقل',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(
                  labelText: 'الصلاحية',
                  prefixIcon: Icon(Icons.shield_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'editor',
                    child: Text('محرر — يضيف أشخاصاً ويكتب بطاقات'),
                  ),
                  DropdownMenuItem(
                    value: 'viewer',
                    child: Text('مشاهد — يطّلع فقط'),
                  ),
                ],
                onChanged: (value) => setState(() => role = value ?? 'editor'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          Navigator.pop(
            context,
            _WorkerDraft(
              username: username.text.trim().toLowerCase(),
              displayName: displayName.text.trim(),
              password: password.text,
              role: role,
            ),
          );
        },
        child: const Text('إنشاء الحساب'),
      ),
    ],
  );
}
