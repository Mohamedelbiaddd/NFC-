import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/repository.dart';
import '../core/app_config.dart';
import 'profile_editor.dart';
import 'qr_screen.dart';
import 'writer_screen.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late final Repository repo;
  List<Json> tenants = [], businesses = [], profiles = [];
  String? tenant, error;
  String role = 'viewer';
  int page = 0, events = 0, request = 0;
  bool loading = true;
  bool get canEdit => {'owner', 'admin', 'editor'}.contains(role);
  bool get canDelete => {'owner', 'admin'}.contains(role);
  @override
  void initState() {
    super.initState();
    repo = Repository(Supabase.instance.client);
    load();
  }

  void notify(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userError(e))));
    }
  }

  Future<void> load({String? selected}) async {
    final ticket = ++request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final ts = await repo.rows('nfc_tenants');
      final t = selected ?? tenant ?? ts.firstOrNull?['id'];
      final active = ts.any((x) => x['id'] == t) ? t : ts.firstOrNull?['id'];
      final bs = active == null
          ? <Json>[]
          : await repo.rows('nfc_businesses', tenant: active);
      final ps = active == null
          ? <Json>[]
          : await repo.rows('nfc_profiles', tenant: active);
      var r = 'viewer';
      var n = 0;
      if (active != null) {
        final m = await repo.client
            .from('nfc_memberships')
            .select('role')
            .eq('tenant_id', active)
            .eq('user_id', repo.client.auth.currentUser!.id)
            .single();
        r = m['role'];
        n = await repo.count('nfc_write_events', active);
      }
      if (mounted && ticket == request) {
        setState(() {
          tenants = ts;
          tenant = active;
          businesses = bs;
          profiles = ps;
          role = r;
          events = n;
        });
      }
    } catch (e) {
      if (mounted && ticket == request) setState(() => error = userError(e));
    } finally {
      if (mounted && ticket == request) setState(() => loading = false);
    }
  }

  Future<bool> confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
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
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: input,
          decoration: InputDecoration(labelText: hint),
          maxLength: 120,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, input.text.trim()),
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

  Future<void> businessForm([Json? b]) async {
    if (tenant == null) return;
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: b?['name'] ?? ''),
        primary = TextEditingController(text: b?['primary_color'] ?? '#7367F0'),
        accent = TextEditingController(text: b?['accent_color'] ?? '#2DD4BF');
    bool saving = false;
    String? err;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: Text(b == null ? 'إضافة نشاط تجاري' : 'تعديل الهوية'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'اسم النشاط'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 14),
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
                  if (err != null) Text(err!),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(c),
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
                        }, id: b?['id']);
                        if (c.mounted) Navigator.pop(c);
                        await load();
                      } catch (e) {
                        if (c.mounted) {
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

  Future<void> profileForm([Json? profile]) async {
    if (tenant == null) return;
    if (businesses.isEmpty) {
      notify('أضف نشاطاً تجارياً أولاً');
      return;
    }
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProfileEditor(
        repo: repo,
        tenant: tenant!,
        businesses: businesses,
        profile: profile,
      ),
    );
    if (changed == true) await load();
  }

  Widget profileThumb() => Container(
    width: 64,
    height: 64,
    color: const Color(0xFF232941),
    child: const Icon(
      Icons.image_not_supported_outlined,
      color: Color(0xFF7C87A8),
    ),
  );

  Uri profileLink(Json p) =>
      AppConfig.profileUrl(AppConfig.profileBase, p['custom_slug'] as String);

  Future<void> openProfile(Json p) async {
    try {
      if (!await launchUrl(
        profileLink(p),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('تعذّر فتح الرابط');
      }
    } catch (e) {
      notify(e);
    }
  }

  void openQr(Json p) {
    final slug = p['custom_slug'] as String?;
    if (slug == null || slug.isEmpty) {
      notify('لا يوجد رابط مخصص لهذا الملف.');
      return;
    }
    try {
      final match = businesses.where((b) => b['id'] == p['business_id']);
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => QrScreen(
            url: profileLink(p).toString(),
            title: '${p['title'] ?? ''}',
            business: match.isEmpty ? '' : '${match.first['name']}',
            slug: slug,
            published: p['published'] == true,
          ),
        ),
      );
    } catch (e) {
      notify(e);
    }
  }

  Future<void> remove(String table, Json x) async {
    if (!await confirm(
      table == 'nfc_businesses'
          ? 'حذف النشاط يحذف ملفاته وسجلاته ويوقف روابطه. الأسماء المخصصة تبقى محجوزة لمنع انتحال البطاقات.'
          : 'سيصبح الرابط غير متاح. الاسم المخصص يبقى محجوزاً.',
    )) {
      return;
    }
    try {
      await repo.delete(table, x['id']);
      await load();
    } catch (e) {
      notify(e);
    }
  }

  Future<void> team() async {
    final email = await ask('إدارة الفريق', 'بريد عضو مسجل مسبقاً');
    if (email == null || email.isEmpty || !mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('صلاحية العضو'),
        children: [
          for (final r in [
            'viewer',
            'editor',
            if (role == 'owner') 'admin',
            'remove',
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, r),
              child: Text(r),
            ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await repo.client.rpc(
        'nfc_set_member',
        params: {
          'workspace_id': tenant,
          'member_email': email,
          'member_role': result,
        },
      );
      notify('تم تحديث العضوية');
    } catch (e) {
      notify(e);
    }
  }

  Widget stat(String label, String value, IconData icon) => SizedBox(
    width: 225,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF9D8DFF)),
            const SizedBox(height: 20),
            Text(
              value,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
  Widget body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!),
            TextButton(onPressed: load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    if (tenant == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: newTenant,
          icon: const Icon(Icons.add_business),
          label: const Text('أنشئ أول مساحة عمل'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            [
              'نظرة عامة',
              'الأنشطة التجارية',
              'ملفات NFC',
              'الفريق والصلاحيات',
            ][page],
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'مساحة عمل معزولة · صلاحيتك: $role',
            style: const TextStyle(color: Color(0xFFA7AEC6)),
          ),
          const SizedBox(height: 24),
          if (page == 0) ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                stat('نشاط تجاري', '${businesses.length}', Icons.storefront),
                stat('ملف رقمي', '${profiles.length}', Icons.layers_outlined),
                stat(
                  'ملف منشور',
                  '${profiles.where((p) => p['published'] == true).length}',
                  Icons.public,
                ),
                stat('عمليات أبلغ عنها التطبيق', '$events', Icons.contactless),
              ],
            ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'ابدأ بإضافة نشاط تجاري، ثم أنشئ ملفاً باسم مخصص مثل bella-napoli. انشر واجهة الويب على نطاق HTTPS قبل برمجة بطاقات العملاء. سجلات الكتابة بلاغات من العميل وليست إثباتاً مادياً من الخادم.',
                ),
              ),
            ),
          ],
          if (page == 1) ...[
            if (canEdit)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: businessForm,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة نشاط'),
                ),
              ),
            const SizedBox(height: 16),
            if (businesses.isEmpty) const Text('لا توجد أنشطة بعد.'),
            for (final b in businesses)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Color(
                      int.parse(
                        'FF${(b['primary_color'] as String).substring(1)}',
                        radix: 16,
                      ),
                    ),
                    child: const Icon(Icons.storefront, color: Colors.white),
                  ),
                  title: Text(b['name']),
                  subtitle: Text(
                    '${b['primary_color']} · ${b['accent_color']}',
                  ),
                  trailing: Wrap(
                    children: [
                      if (canEdit)
                        IconButton(
                          onPressed: () => businessForm(b),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      if (canDelete)
                        IconButton(
                          onPressed: () => remove('nfc_businesses', b),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                ),
              ),
          ],
          if (page == 2) ...[
            if (canEdit)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: profileForm,
                  icon: const Icon(Icons.add),
                  label: const Text('إنشاء ملف NFC'),
                ),
              ),
            const SizedBox(height: 16),
            if (profiles.isEmpty) const Text('لا توجد ملفات بعد.'),
            for (final p in profiles)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p['image_url'] is String &&
                          (p['image_url'] as String).startsWith('https://'))
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 14),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              p['image_url'] as String,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => profileThumb(),
                              loadingBuilder: (_, child, progress) =>
                                  progress == null ? child : profileThumb(),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['title'],
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${kindNames[p['kind']]} · ${p['published'] ? 'منشور' : 'مسودة'}',
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              '/p/${p['custom_slug']}',
                              textDirection: TextDirection.ltr,
                            ),
                            Wrap(
                              children: [
                                if (canEdit)
                                  TextButton.icon(
                                    onPressed: () => profileForm(p),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('تعديل'),
                                  ),
                                TextButton.icon(
                                  onPressed: () => openProfile(p),
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('معاينة'),
                                ),
                                TextButton.icon(
                                  onPressed: () => openQr(p),
                                  icon: const Icon(Icons.qr_code_2),
                                  label: const Text('رمز QR للطباعة'),
                                ),
                                if (canEdit)
                                  TextButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => WriterScreen(
                                          repo: repo,
                                          tenant: tenant!,
                                          profileId: p['id'],
                                        ),
                                      ),
                                    ).then((_) => load()),
                                    icon: const Icon(Icons.nfc),
                                    label: const Text('برمجة البطاقة'),
                                  ),
                                if (canDelete)
                                  IconButton(
                                    onPressed: () => remove('nfc_profiles', p),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (page == 3) ...[
            const Text(
              'الأدوار: owner / admin / editor / viewer. العضو يسجّل حسابه أولاً، ثم تضيفه بالبريد. لا يستطيع العميل تغيير tenant_id أو ترقية نفسه عبر قاعدة البيانات.',
            ),
            const SizedBox(height: 20),
            if (canDelete)
              FilledButton(
                onPressed: team,
                child: const Text('إضافة / تعديل / إزالة عضو مسجل'),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 820;
    final destinations = const [
      (Icons.space_dashboard_outlined, 'الرئيسية'),
      (Icons.storefront_outlined, 'الأنشطة'),
      (Icons.contactless_outlined, 'ملفات NFC'),
      (Icons.group_outlined, 'الفريق'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Studio'),
        actions: [
          if (tenants.isNotEmpty)
            SizedBox(
              width: MediaQuery.sizeOf(context).width < 500 ? 140 : 220,
              child: DropdownButton<String>(
                value: tenant,
                isExpanded: true,
                items: tenants
                    .map(
                      (t) => DropdownMenuItem<String>(
                        value: t['id'],
                        child: Text(t['name'], overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: loading ? null : (v) => load(selected: v),
              ),
            ),
          IconButton(
            tooltip: 'مساحة جديدة',
            onPressed: newTenant,
            icon: const Icon(Icons.add_business_outlined),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await repo.client.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: page,
              extended: true,
              onDestinationSelected: (i) => setState(() => page = i),
              destinations: destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: Icon(d.$1),
                      label: Text(d.$2),
                    ),
                  )
                  .toList(),
            ),
          Expanded(child: body()),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: page,
              onDestinationSelected: (i) => setState(() => page = i),
              destinations: destinations
                  .map(
                    (d) => NavigationDestination(icon: Icon(d.$1), label: d.$2),
                  )
                  .toList(),
            ),
    );
  }
}
