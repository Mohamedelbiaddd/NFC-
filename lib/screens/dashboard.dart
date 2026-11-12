import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/i18n.dart';

import '../core/app_config.dart';
import '../core/people.dart';
import '../core/repository.dart';
import '../core/theme.dart';
import '../core/update_service.dart';
import '../core/workers_service.dart';
import 'activity_tab.dart';
import 'people_tab.dart';
import 'person_form.dart';
import 'qr_screen.dart';
import 'users_tab.dart';
import 'link_writer_screen.dart';
import 'network_tab.dart';
import 'shops_tab.dart';
import 'site_users_screen.dart';
import '../core/network_service.dart';
import '../core/shops_service.dart';
import 'writer_screen.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late final Repository repo;
  late final WorkersService workers;
  late final ShopsService shops;
  late final NetworkService network;
  String staffRole = '';
  String? staffNotice;
  bool allowed = true, accountChecked = false;
  List<Json> tenants = const [], businesses = const [], profiles = const [];
  String? tenant, error;
  String role = 'viewer';
  bool isSuper = false, loading = true, _loggedLogin = false;
  int page = 0, request = 0, tick = 0;
  final networkAdd = ValueNotifier<int>(0);
  Map<String, int> profileScans = const {};
  int totalScans = 0;
  bool get seesNetwork => isSuper || staffRole == 'agent';
  int get tabCount => !canEdit ? 1 : 1 + (seesNetwork ? 1 : 0) + (isSuper ? 2 : 0);

  bool get canEdit => {'owner', 'admin', 'editor'}.contains(role);
  bool get canDelete => {'owner', 'admin'}.contains(role);
  bool get canManage => canDelete;

  @override
  void initState() {
    super.initState();
    repo = Repository(Supabase.instance.client);
    workers = WorkersService(repo.client);
    shops = ShopsService(repo.client);
    network = NetworkService(repo.client);
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
      var ts = await repo.rows('nfc_tenants');
      final me = repo.client.auth.currentUser?.id;
      // No workspace yet: one is created silently (nobody needs to name it).
      if (ts.where((t) => '${t['owner_id']}' == me).isEmpty && selected == null && tenant == null) {
        try {
          final acc = await network.myAccount();
          if (acc['allowed'] != false) {
            await repo.client.rpc('nfc_create_workspace', params: {'workspace_name': tr('مساحتي')});
            ts = await repo.rows('nfc_tenants');
          }
        } catch (_) {}
      }
      final mine = ts.where((t) => '${t['owner_id']}' == me).firstOrNull;
      final candidate =
          selected ?? tenant ?? '${(mine ?? ts.firstOrNull)?['id'] ?? ''}';
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
      var account = <String, dynamic>{};
      try {
        account = await network.myAccount();
      } catch (_) {
        // Older databases: treat as allowed; RLS still protects the data.
        account = {'allowed': true};
      }
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
        allowed = account['allowed'] != false;
        accountChecked = true;
        final staff = account['staff'];
        staffRole = staff is Map ? '${staff['role'] ?? ''}' : '';
        staffNotice = staff is Map && staff['notice'] != null ? '${staff['notice']}' : null;
        profileScans = scans;
        totalScans = scanTotal;
        if (page >= tabCount) page = 0;
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
    if (!await _ensureCardSpace() || !mounted) return;
    final saved = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PersonForm(
        repo: repo,
        tenant: tenant!,
        businesses: businesses,
      ),
    );
    if (saved != null) {
      setState(() => page = 0);
      await refresh();
      if (!mounted) return;
      final profile = profiles.where((p) => '${p['id']}' == '$saved').firstOrNull;
      if (profile != null) {
        await cardReady(profile);
      } else {
        _snack(tr('تم حفظ الشخص وأصبح في القائمة.'));
      }
    }
  }

  /// Right after a new card is saved: its link, copy, QR and "write to NFC".
  Future<void> cardReady(Json profile) async {
    final link = profileLink(profile).toString();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 52),
              const SizedBox(height: 8),
              Text(
                tr('البطاقة جاهزة ✅'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                personName(profile),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        link,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 13, color: AppColors.accent),
                      ),
                    ),
                    IconButton(
                      tooltip: tr('نسخ الرابط'),
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: link));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تم نسخ الرابط'))));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () {
                  Navigator.pop(ctx);
                  openWriter(profile);
                },
                icon: const Icon(Icons.nfc_rounded),
                label: Text(tr('اكتب الرابط على بطاقة NFC')),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        openQr(profile);
                      },
                      icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                      label: Text(tr('رمز QR')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openProfile(profile),
                      icon: const Icon(Icons.open_in_new_rounded, size: 20),
                      label: Text(tr('فتح البطاقة')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> editPerson(Json profile) async {
    if (tenant == null) return;
    final saved = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PersonForm(
        repo: repo,
        tenant: tenant!,
        businesses: businesses,
        profile: profile,
      ),
    );
    if (saved != null) await refresh();
  }

  Future<void> deletePerson(Json profile) async {
    if (!await confirm(trf('سيصبح رابط «{0}» غير متاح. الاسم المخصص يبقى محجوزاً لمنع انتحال البطاقات.', [personName(profile)]))) {
      return;
    }
    try {
      await repo.delete('nfc_profiles', '${profile['id']}');
      await refresh();
      _snack(tr('تم حذف البطاقة.'));
    } catch (e) {
      notify(e);
    }
  }

  Uri profileLink(Json profile) => AppConfig.profileUrl(
    AppConfig.profileBase,
    '${profile['custom_slug']}',
  );

  /// "Change owner password" from a loyalty card in the people list.
  Future<void> shopPasswordFromCard(Json profile, String slug) async {
    try {
      final rows = await network.shops();
      final shop = rows.where((s) => '${s['shop_slug']}' == slug).firstOrNull;
      if (!mounted) return;
      if (shop == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('لم أجد هذا المحل في شبكتك.')), backgroundColor: AppColors.danger),
        );
        return;
      }
      await resetShopOwnerPassword(context, shops, shop);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userError(e)), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> openProfile(Json profile) async {
    try {
      if (!await launchUrl(
        profileLink(profile),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError(tr('تعذّر فتح الرابط'));
      }
    } catch (e) {
      notify(e);
    }
  }

  Future<void> openQr(Json profile) async {
    final slug = '${profile['custom_slug'] ?? ''}';
    if (slug.isEmpty) {

      _snack(tr('لا يوجد رابط مخصص لهذا الشخص.'));
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
          title: Text(tr('تأكيد الحذف')),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('إلغاء')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('حذف')),
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
            child: Text(tr('إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: Text(tr('متابعة')),
          ),
        ],
      ),
    );
    // Dialog routes are disposed after their exit animation.
    Future.delayed(const Duration(seconds: 1), input.dispose);
    return value;
  }

  Future<void> newTenant() async {
    final name = await ask(tr('مساحة عمل جديدة'), tr('اسم المساحة'));
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
          title: Text(business == null ? tr('إضافة نشاط تجاري') : tr('تعديل الهوية')),
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
                      decoration: InputDecoration(
                        labelText: tr('اسم النشاط'),
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? tr('مطلوب') : null,
                    ),
                    const SizedBox(height: 10),
                    for (final pair in [
                      (primary, tr('اللون الأساسي')),
                      (accent, tr('لون التمييز')),
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
                              : tr('صيغة #RRGGBB'),
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
              child: Text(tr('إلغاء')),
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
              child: Text(saving ? tr('جارٍ الحفظ…') : tr('حفظ')),
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

  /// "+" : what to add. A business card or a shop of any sector; then the
  /// form for that choice only. Admins and agents also see "app account".
  Future<void> _plusMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        Widget tile(String key, String icon, String label, {Color? color}) => InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.pop(context, key),
              child: Container(
                decoration: BoxDecoration(
                  color: (color ?? AppColors.surfaceHigh).withValues(alpha: color == null ? 1 : 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color ?? AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 30)),
                    const SizedBox(height: 6),
                    Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
            );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('ماذا تريد أن تضيف؟'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: [
                    tile('card', '💼', tr('بطاقة أعمال'), color: AppColors.primary),
                    for (final e in ShopsService.industries.entries) tile('shop:${e.key}', e.value.$1, e.value.$2),
                  ],
                ),
                if (seesNetwork) ...[
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.manage_accounts_rounded, color: AppColors.accent),
                    title: Text(tr('حساب جديد للتطبيق (بالبريد الإلكتروني)'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(tr('الاسم والبريد، وكلمة المرور تُنشأ تلقائياً وترسلها له')),
                    onTap: () => Navigator.pop(context, 'account'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    if (choice == 'card') return addPerson();
    if (choice.startsWith('shop:')) return addShop(choice.substring(5));
    setState(() => page = 1); // the Network tab
    await Future<void>.delayed(const Duration(milliseconds: 250));
    networkAdd.value++;
  }

  /// A new shop of the chosen sector; it then shows in the home list.
  Future<void> addShop(String industry) async {
    if (tenant == null) return;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => ShopForm(service: shops, tenant: tenant!, initialIndustry: industry)),
    );
    if (result != null && mounted) setState(() => tick++);
  }

  /// Business cards need a workspace and a business behind them: both are
  /// created silently the first time, the user never has to name them.
  Future<bool> _ensureCardSpace() async {
    try {
      if (tenant == null) {
        final id = await repo.client.rpc('nfc_create_workspace', params: {'workspace_name': tr('مساحتي')});
        await load(selected: id as String, silent: true);
      }
      if (tenant != null && businesses.isEmpty) {
        await repo.save('nfc_businesses', {
          'tenant_id': tenant,
          'name': tr('بطاقات الأعمال'),
          'industry': 'other',
          'primary_color': '#7367F0',
          'accent_color': '#2DD4BF',
        });
        await load(selected: tenant, silent: true);
      }
    } catch (e) {
      notify(e);
    }
    return tenant != null && businesses.isNotEmpty;
  }

  /// A business card in the home list: photo, name, job, link / NFC / edit.
  Widget _cardTile(Json profile) {
    final image = '${profile['image_url'] ?? ''}';
    final data = profile['data'] is Map ? profile['data'] as Map : const {};
    final job = '${data['job_title'] ?? ''}';
    final scans = profileScans['${profile['id']}'] ?? 0;
    final published = personPublished(profile);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => editPerson(profile),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.4),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primarySoft, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: image.startsWith('https://')
                        ? Image.network(image, fit: BoxFit.cover, width: 50, height: 50,
                            errorBuilder: (_, __, ___) => const Text('💼', style: TextStyle(fontSize: 22)))
                        : const Text('💼', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(personName(profile), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(
                          [tr('بطاقة أعمال'), if (job.isNotEmpty) job].join(' · '),
                          style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr('تعديل البطاقة'),
                    onPressed: () => editPerson(profile),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Pill(trf('{0} زيارة للبطاقة', [scans]), color: AppColors.accent),
                  if (!published) Pill(tr('غير منشورة'), color: AppColors.warning),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => cardReady(profile),
                      icon: const Icon(Icons.link_rounded, size: 16),
                      label: Text(tr('الرابط'), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openWriter(profile),
                      icon: const Icon(Icons.nfc_rounded, size: 16),
                      label: Text(tr('NFC'), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: canDelete ? () => deletePerson(profile) : null,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: Text(tr('حذف'), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNfcTools() => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => LinkWriterScreen(repo: repo, tenant: tenant)),
  );

  Widget _addButton() {
    final wide = MediaQuery.sizeOf(context).width >= 430;
    final onPressed = canEdit && tenant != null ? _plusMenu : null;
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
        label: Text(tr('إضافة')),
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

  /// Change my own password (re-checks the current one first).
  Future<void> changeMyPassword() async {
    final current = TextEditingController(), next = TextEditingController(), again = TextEditingController();
    String? err;
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(tr('تغيير كلمة المرور')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: current, obscureText: true, decoration: InputDecoration(labelText: tr('كلمة المرور الحالية'))),
              const SizedBox(height: 8),
              TextField(controller: next, obscureText: true, decoration: InputDecoration(labelText: tr('كلمة المرور الجديدة (8 أحرف على الأقل)'))),
              const SizedBox(height: 8),
              TextField(controller: again, obscureText: true, decoration: InputDecoration(labelText: tr('أعد كتابة كلمة المرور الجديدة'))),
              if (err != null) ...[
                const SizedBox(height: 10),
                Text(err!, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: Text(tr('إلغاء'))),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (next.text.length < 8) return setLocal(() => err = tr('كلمة المرور الجديدة قصيرة (8 أحرف على الأقل).'));
                      if (next.text != again.text) return setLocal(() => err = tr('كلمتا المرور غير متطابقتين.'));
                      setLocal(() { busy = true; err = null; });
                      try {
                        final email = repo.client.auth.currentUser?.email ?? '';
                        await repo.client.auth.signInWithPassword(email: email, password: current.text);
                        await repo.client.auth.updateUser(UserAttributes(password: next.text));
                        if (context.mounted) Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text(tr('تم تغيير كلمة المرور.')), backgroundColor: AppColors.success),
                          );
                        }
                      } on AuthException catch (e) {
                        setLocal(() {
                          busy = false;
                          err = e.message.toLowerCase().contains('invalid') ? tr('كلمة المرور الحالية غير صحيحة.') : userError(e);
                        });
                      } catch (e) {
                        setLocal(() { busy = false; err = userError(e); });
                      }
                    },
              child: Text(busy ? tr('جارٍ الحفظ…') : tr('حفظ')),
            ),
          ],
        ),
      ),
    );
  }

  /// Delete the selected workspace (owner or super admin; refused while its
  /// loyalty shops have customers).
  Future<void> deleteWorkspace([String? id]) async {
    final target = id ?? tenant;
    final current = tenants.where((t) => '${t['id']}' == target).firstOrNull;
    if (current == null) return;
    final name = '${current['name']}';
    final typed = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(tr('حذف مساحة العمل')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(trf('ستُحذف «{0}» نهائياً مع بطاقاتها وأنشطتها. لا يمكن التراجع.', [name])),
              const SizedBox(height: 10),
              Text(tr('للتأكيد اكتب اسمها:'), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              TextField(controller: typed, onChanged: (_) => setLocal(() {})),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('إلغاء'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: typed.text.trim() == name.trim() ? () => Navigator.pop(context, true) : null,
              child: Text(tr('حذف')),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final r = await repo.client.rpc('nfc_delete_workspace', params: {'target': target});
      final res = r is Map ? r : const {};
      if (res['ok'] == true) {
        if (target == tenant) tenant = null;
        await load(selected: tenant);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تم حذف مساحة العمل.'))));
        }
        return;
      }
      final msg = switch ('${res['error']}') {
        'has_customers' => tr('فيها محل له زبائن ونقاط، فلا يمكن حذفها. أوقف المحل بدل ذلك.'),
        'forbidden' => tr('ليست لديك صلاحية حذف هذه المساحة.'),
        _ => tr('تعذّر الحذف.'),
      };
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
    } catch (e) {
      notify(e);
    }
  }

  /// Workspaces in a sheet: search, "mine / everyone's" (super admin) and a
  /// delete button next to each one.
  bool showAllWorkspaces = false;
  Future<void> _pickWorkspace() async {
    final me = repo.client.auth.currentUser?.id;
    var query = '';
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final list = tenants.where((t) {
            final mine = '${t['owner_id']}' == me || '${t['id']}' == tenant;
            if (isSuper && !showAllWorkspaces && !mine) return false;
            return query.isEmpty || '${t['name']}'.toLowerCase().contains(query.toLowerCase());
          }).toList();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(sheetContext).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('مساحات العمل'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: tr('بحث')),
                    onChanged: (v) => setSheet(() => query = v.trim()),
                  ),
                  if (isSuper)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: showAllWorkspaces,
                      title: Text(tr('عرض مساحات كل المستخدمين')),
                      onChanged: (v) => setSheet(() => showAllWorkspaces = v),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.add_box_outlined, color: AppColors.accent),
                    title: Text(tr('مساحة عمل جديدة')),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      newTenant();
                    },
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.5),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (list.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(tr('لا شيء هنا.'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
                          ),
                        for (final t in list)
                          ListTile(
                            selected: '${t['id']}' == tenant,
                            leading: Icon('${t['owner_id']}' == me ? Icons.workspaces_rounded : Icons.workspaces_outline),
                            title: Text('${t['name']}', overflow: TextOverflow.ellipsis),
                            subtitle: '${t['owner_id']}' == me ? Text(tr('مساحتي'), style: const TextStyle(fontSize: 11)) : null,
                            onTap: () => Navigator.pop(sheetContext, '${t['id']}'),
                            trailing: IconButton(
                              tooltip: tr('حذف مساحة العمل'),
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                deleteWorkspace('${t['id']}');
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (picked == null || picked == tenant || !mounted) return;
    setState(() => page = 0);
    load(selected: picked);
  }

  Widget _body() {
    if (!accountChecked) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!allowed && !loading) {
      return EmptyState(
        icon: Icons.lock_outline_rounded,
        title: tr('هذا الحساب غير مفعّل'),
        text: tr('الحسابات تُنشأ فقط من طرف الإدارة أو الوكيل المسؤول. إذا كان حسابك موقوفاً تواصل مع المسؤول عنك.'),
        action: FilledButton.icon(
          onPressed: signOut,
          icon: const Icon(Icons.logout_rounded),
          label: Text(tr('تسجيل الخروج')),
        ),
      );
    }
    if (error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: tr('تعذّر تحميل البيانات'),
        text: error!,
        action: FilledButton.icon(
          onPressed: () => load(),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(tr('إعادة المحاولة')),
        ),
      );
    }
    if (tenants.isEmpty && !loading) {
      return EmptyState(
        icon: Icons.workspaces_outline,
        title: tr('لا توجد مساحة عمل'),
        text: tr('أنشئ مساحة عمل لتبدأ بإضافة الأشخاص وكتابة بطاقات NFC.'),
        action: FilledButton.icon(
          onPressed: newTenant,
          icon: const Icon(Icons.add_rounded),
          label: Text(tr('مساحة عمل جديدة')),
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
      onShopPassword: shopPasswordFromCard,
      scans: profileScans,
      totalScans: totalScans,
    );
    if (!canEdit) return people;
    return IndexedStack(
      index: page.clamp(0, tabCount - 1).toInt(),
      children: [
        ShopsTab(
          key: ValueKey('shops-$tick-${tenant!}'),
          service: shops,
          network: network,
          tenant: tenant!,
          seeAll: seesNetwork,
          cards: profiles.where((p) => '${p['kind']}' != 'loyalty').toList(),
          cardTile: _cardTile,
          onAdd: _plusMenu,
        ),
        if (seesNetwork)
          NetworkTab(
            key: ValueKey('network-$tick'),
            service: network,
            isSuper: isSuper,
            shops: shops,
            tenant: tenant!,
            openAdd: networkAdd,
          ),
        if (isSuper)
          ActivityTab(
            key: ValueKey('activity-$tick-${tenant!}'),
            service: workers,
            tenant: tenant!,
            currentUserId: repo.client.auth.currentUser?.id,
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
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset('assets/brand/logo.png', width: 34, height: 34),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('TapMaroc', style: TextStyle(fontSize: 16)),
                Text(
                  isSuper ? tr('مدير عام · صلاحيات كاملة') : tr('لوحة الإدارة'),
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
          const LanguageButton(),
          _addButton(),
          const SizedBox(width: 4),
          IconButton(
            tooltip: tr('📡 أدوات NFC'),
            onPressed: _openNfcTools,
            icon: const Icon(Icons.nfc_rounded, size: 24, color: AppColors.success),
          ),
          PopupMenuButton<String>(
            tooltip: tr('المزيد'),
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              switch (v) {
                case 'refresh':
                  load();
                case 'workspaces':
                  _pickWorkspace();
                case 'site_users':
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => SiteUsersScreen(client: repo.client)));
                case 'password':
                  changeMyPassword();
                case 'logout':
                  signOut();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'refresh', child: ListTile(leading: const Icon(Icons.sync_rounded), title: Text(tr('تحديث')))),
              if (tenants.length > 1 || isSuper)
                PopupMenuItem(value: 'workspaces', child: ListTile(leading: const Icon(Icons.workspaces_outline), title: Text(tr('مساحات العمل')))),
              if (isSuper)
                PopupMenuItem(value: 'site_users', child: ListTile(leading: const Icon(Icons.public_rounded), title: Text(tr('مسجّلو الموقع')))),
              PopupMenuItem(value: 'password', child: ListTile(leading: const Icon(Icons.key_rounded), title: Text(tr('تغيير كلمة المرور')))),
              PopupMenuItem(value: 'logout', child: ListTile(leading: const Icon(Icons.logout_rounded, color: AppColors.danger), title: Text(tr('تسجيل الخروج')))),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          const UpdateBanner(),
          if (staffNotice != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.6)),
              ),
              child: Text('⚠️ $staffNotice', style: const TextStyle(height: 1.5)),
            ),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: canEdit && allowed && tenant != null
          ? NavigationBar(
              selectedIndex: page.clamp(0, tabCount - 1).toInt(),
              onDestinationSelected: (index) => setState(() => page = index),
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: tr('الرئيسية'),
                ),
                if (seesNetwork)
                  NavigationDestination(
                    icon: Icon(Icons.hub_outlined),
                    selectedIcon: Icon(Icons.hub_rounded),
                    label: tr('الشبكة'),
                  ),
                if (isSuper)
                  NavigationDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights_rounded),
                    label: tr('المتابعة'),
                  ),
                if (isSuper)
                  NavigationDestination(
                    icon: Icon(Icons.shield_outlined),
                    selectedIcon: Icon(Icons.shield_rounded),
                    label: tr('المستخدمون'),
                  ),
              ],
            )
          : null,
    );
  }
}
