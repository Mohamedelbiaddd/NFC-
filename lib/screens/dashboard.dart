import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import '../core/people.dart';
import '../core/repository.dart';
import '../core/theme.dart';
import '../core/workers_service.dart';
import 'activity_tab.dart';
import 'people_tab.dart';
import 'person_form.dart';
import 'qr_screen.dart';
import 'users_tab.dart';
import 'link_writer_screen.dart';
import 'workers_tab.dart';
import 'writer_screen.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late final Repository repo;
  late final WorkersService workers;
  List<Json> tenants = const [], businesses = const [], profiles = const [];
  String? tenant, error;
  String role = 'viewer';
  bool isSuper = false, loading = true, _loggedLogin = false;
  int page = 0, request = 0, tick = 0;
  Map<String, int> profileScans = const {};
  int totalScans = 0;
  int get tabCount => isSuper ? 4 : 3;

  bool get canEdit => {'owner', 'admin', 'editor'}.contains(role);
  bool get canDelete => {'owner', 'admin'}.contains(role);
  bool get canManage => canDelete;

  @override
  void initState() {
    super.initState();
    repo = Repository(Supabase.instance.client);
    workers = WorkersService(repo.client);
    load();
  }

  void notify(Object e) => _snack(userError(e), error: true);

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.surfaceHigh,
      ),
    );
  }

  Future<void> load({String? selected, bool silent = false}) async {
    final ticket = ++request;
    if (!silent) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final ts = await repo.rows('nfc_tenants');
      final candidate =
          selected ?? tenant ?? (ts.isEmpty ? null : '${ts.first['id']}');
      final active = ts.any((x) => '${x['id']}' == candidate)
          ? candidate
          : (ts.isEmpty ? null : '${ts.first['id']}');
      final bs = active == null
          ? <Json>[]
          : await repo.rows('nfc_businesses', tenant: active);
      final ps = active == null
          ? <Json>[]
          : await repo.rows('nfc_profiles', tenant: active);
      ps.sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
      var scans = <String, int>{};
      var scanTotal = 0;
      if (active != null) {
        try {
          final rows = await workers.scanOverview(active);
          for (final row in rows) {
            final count = row['scans'];
            final value = count is int ? count : int.tryParse('$count') ?? 0;
            scans['${row['profile_id']}'] = value;
            scanTotal += value;
          }
        } catch (_) {
          // Scan counters are informative; never block the workspace load.
        }
      }
      var superAdmin = false;
      var current = 'viewer';
      if (active != null) {
        superAdmin = await repo.amSuperAdmin();
        try {
          final membership = await repo.client
              .from('nfc_memberships')
              .select('role')
              .eq('tenant_id', active)
              .eq('user_id', repo.client.auth.currentUser!.id)
              .maybeSingle();
          final value = '${membership?['role'] ?? ''}';
          if (value.isNotEmpty && value != 'null') current = value;
        } catch (_) {
          // A super admin may hold no explicit membership row.
        }
        if (superAdmin) current = 'owner';
      }
      if (!mounted || ticket != request) return;
      setState(() {
        tenants = ts;
        tenant = active;
        businesses = bs;
        profiles = ps;
        role = current;
        isSuper = superAdmin;
        profileScans = scans;
        totalScans = scanTotal;
        if (page > 0 && !canManage) page = 0;
        if (page == 3 && !superAdmin) page = 0;
      });
      if (active != null && !_loggedLogin) {
        _loggedLogin = true;
        await repo.logEvent(
          active,
          'login',
          subject: repo.client.auth.currentUser?.email,
        );
      }
    } catch (e) {
      if (mounted && ticket == request) setState(() => error = userError(e));
    } finally {
      if (mounted && ticket == request) setState(() => loading = false);
    }
  }

  Future<void> refresh() async {
    await load(silent: true);
    if (mounted) setState(() => tick++);
  }

  Future<void> addPerson() async {
    if (tenant == null) {
      _snack('أنشئ مساحة عمل أولاً.');
      return;
    }
    if (businesses.isEmpty) {
      _snack('أضف نشاطاً تجارياً أولاً.');
      await businessForm();
      return;
    }
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PersonForm(
        repo: repo,
        tenant: tenant!,
        businesses: businesses,
      ),
    );
    if (changed == true) {
      setState(() => page = 0);
      await refresh();
      _snack('تم حفظ الشخص وأصبح في القائمة.');
    }
  }

  Future<void> editPerson(Json profile) async {
    if (tenant == null) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PersonForm(
        repo: repo,
        tenant: tenant!,
        businesses: businesses,
        profile: profile,
      ),
    );
    if (changed == true) await refresh();
  }

  Future<void> deletePerson(Json profile) async {
    if (!await confirm('سيصبح رابط «${personName(profile)}» غير متاح. '
        'الاسم المخصص يبقى محجوزاً لمنع انتحال البطاقات.')) {
      return;
    }
    try {
      await repo.delete('nfc_profiles', '${profile['id']}');
      await refresh();
      _snack('تم حذف البطاقة.');
    } catch (e) {
      notify(e);
    }
  }

  Uri profileLink(Json profile) => AppConfig.profileUrl(
    AppConfig.profileBase,
    '${profile['custom_slug']}',
  );

  Future<void> openProfile(Json profile) async {
    try {
      if (!await launchUrl(
        profileLink(profile),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('تعذّر فتح الرابط');
      }
    } catch (e) {
      notify(e);
    }
  }

  Future<void> openQr(Json profile) async {
    final slug = '${profile['custom_slug'] ?? ''}';
    if (slug.isEmpty) {

      _snack('لا يوجد رابط مخصص لهذا الشخص.');
      return;
    }
    final match = businesses.where((b) => b['id'] == profile['business_id']);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => QrScreen(
          url: profileLink(profile)
              .replace(queryParameters: {'src': 'qr'})
              .toString(),
          title: personName(profile),
          business: match.isEmpty ? '' : '${match.first['name']}',
          slug: slug,
          published: personPublished(profile),
          onSaved: () async {
            if (tenant != null) {
              await repo.logEvent(tenant!, 'qr_saved', subject: personName(profile));
            }
          },
        ),
      ),
    );
    if (mounted) setState(() => tick++);
  }

  Future<void> openWriter(Json profile) async {
    if (tenant == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => WriterScreen(
          repo: repo,
          tenant: tenant!,
          profileId: '${profile['id']}',
          profileName: personName(profile),
        ),
      ),
    );
    await refresh();
  }

  Future<bool> confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ) ??
      false;

  Future<String?> ask(String title, String hint) async {
    final input = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: input,
          maxLength: 120,
          decoration: InputDecoration(labelText: hint),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    // Dialog routes are disposed after their exit animation.
    Future.delayed(const Duration(seconds: 1), input.dispose);
    return value;
  }

  Future<void> newTenant() async {
    final name = await ask('مساحة عمل جديدة', 'اسم المساحة');
    if (name == null || name.isEmpty) return;
    try {
      final id = await repo.client.rpc(
        'nfc_create_workspace',
        params: {'workspace_name': name},
      );
      await load(selected: id as String);
    } catch (e) {
      notify(e);
    }
  }

  Future<void> businessForm([Json? business]) async {
    if (tenant == null) return;
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: business?['name'] ?? ''),
        primary = TextEditingController(
          text: business?['primary_color'] ?? '#7367F0',
        ),
        accent = TextEditingController(
          text: business?['accent_color'] ?? '#2DD4BF',
        );
    bool saving = false;
    String? err;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(business == null ? 'إضافة نشاط تجاري' : 'تعديل الهوية'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'اسم النشاط',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 10),
                    for (final pair in [
                      (primary, 'اللون الأساسي'),
                      (accent, 'لون التمييز'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: TextFormField(
                          controller: pair.$1,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: '${pair.$2} · #RRGGBB',
                          ),
                          validator: (v) =>
                              RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v ?? '')
                              ? null
                              : 'صيغة #RRGGBB',
                        ),
                      ),
                    if (err != null)
                      Text(err!, style: const TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      update(() => saving = true);
                      try {
                        await repo.save('nfc_businesses', {
                          'tenant_id': tenant,
                          'name': name.text.trim(),
                          'primary_color': primary.text,
                          'accent_color': accent.text,
                        }, id: business?['id']);
                        if (context.mounted) Navigator.pop(context);
                        await load(silent: true);
                      } catch (e) {
                        if (context.mounted) {
                          update(() {
                            err = userError(e);
                            saving = false;
                          });
                        }
                      }
                    },
              child: Text(saving ? 'جارٍ الحفظ…' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      name.dispose();
      primary.dispose();
      accent.dispose();
    });
  }

  Future<void> signOut() async {
    try {
      await repo.client.auth.signOut();
    } catch (e) {
      notify(e);
    }
  }

  Widget _addButton() {
    final wide = MediaQuery.sizeOf(context).width >= 430;
    final onPressed = canEdit && tenant != null ? addPerson : null;
    if (!wide) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ),
          child: const Icon(Icons.add_rounded, size: 24),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('إضافة شخص'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _workspaceBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.workspaces_outline,
            size: 18,
            color: AppColors.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: tenant,
                isExpanded: true,
                hint: const Text('اختر مساحة عمل'),
                borderRadius: BorderRadius.circular(16),
                dropdownColor: AppColors.surfaceHigh,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
                items: tenants
                    .map(
                      (t) => DropdownMenuItem<String>(
                        value: '${t['id']}',
                        child: Text(
                          '${t['name']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null || value == tenant) return;
                  setState(() => page = 0);
                  load(selected: value);
                },
              ),
            ),
          ),
          IconButton(
            tooltip: 'مساحة عمل جديدة',
            onPressed: newTenant,
            icon: const Icon(Icons.add_box_outlined, size: 20),
          ),
          IconButton(
            tooltip: businesses.isEmpty ? 'أضف نشاطاً تجارياً' : 'النشاط التجاري',
            onPressed: tenant == null || !canEdit ? null : () => businessForm(),
            icon: const Icon(Icons.storefront_outlined, size: 20),
          ),
        ],
      ),
    ),
  );

  Widget _body() {
    if (error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'تعذّر تحميل البيانات',
        text: error!,
        action: FilledButton.icon(
          onPressed: () => load(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
        ),
      );
    }
    if (tenants.isEmpty && !loading) {
      return EmptyState(
        icon: Icons.workspaces_outline,
        title: 'لا توجد مساحة عمل',
        text: 'أنشئ مساحة عمل لتبدأ بإضافة الأشخاص وكتابة بطاقات NFC.',
        action: FilledButton.icon(
          onPressed: newTenant,
          icon: const Icon(Icons.add_rounded),
          label: const Text('مساحة عمل جديدة'),
        ),
      );
    }
    if (tenant == null || (loading && profiles.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    final people = PeopleTab(
      profiles: profiles,
      loading: loading,
      canEdit: canEdit,
      canDelete: canDelete,
      onCreate: addPerson,
      onEdit: editPerson,
      onDelete: deletePerson,
      onQr: openQr,
      onWrite: openWriter,
      onPreview: openProfile,
      onRefresh: refresh,
      scans: profileScans,
      totalScans: totalScans,
    );
    if (!canManage) return people;
    return IndexedStack(
      index: page.clamp(0, tabCount - 1).toInt(),
      children: [
        people,
        ActivityTab(
          key: ValueKey('activity-$tick-${tenant!}'),
          service: workers,
          tenant: tenant!,
          currentUserId: repo.client.auth.currentUser?.id,
        ),
        WorkersTab(
          key: ValueKey('workers-$tick-${tenant!}'),
          service: workers,
          repo: repo,
          tenant: tenant!,
          onChanged: refresh,
        ),
        if (isSuper)
          UsersTab(
            key: ValueKey('users-$tick'),
            service: workers,
            currentUserId: repo.client.auth.currentUser?.id,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primarySoft],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.contactless_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('NFC Studio', style: TextStyle(fontSize: 16)),
                Text(
                  isSuper ? 'مدير عام · صلاحيات كاملة' : 'لوحة الإدارة',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          _addButton(),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'رابط مباشر على بطاقة NFC',
            onPressed: canEdit
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => LinkWriterScreen(repo: repo, tenant: tenant),
                    ),
                  )
                : null,
            icon: const Icon(Icons.add_link_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: loading ? null : () => load(),
            icon: const Icon(Icons.sync_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: signOut,
            icon: const Icon(Icons.logout_rounded, size: 20),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          _workspaceBar(),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: canManage && tenant != null
          ? NavigationBar(
              selectedIndex: page.clamp(0, tabCount - 1).toInt(),
              onDestinationSelected: (index) => setState(() => page = index),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.people_alt_outlined),
                  selectedIcon: Icon(Icons.people_alt_rounded),
                  label: 'الأشخاص',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights_rounded),
                  label: 'المتابعة',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.badge_outlined),
                  selectedIcon: Icon(Icons.badge_rounded),
                  label: 'الفريق',
                ),
                if (isSuper)
                  const NavigationDestination(
                    icon: Icon(Icons.shield_outlined),
                    selectedIcon: Icon(Icons.shield_rounded),
                    label: 'المستخدمون',
                  ),
              ],
            )
          : null,
    );
  }
}
