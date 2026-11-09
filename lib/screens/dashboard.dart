import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/i18n.dart';

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
import 'network_tab.dart';
import 'shops_tab.dart';
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
  bool allowed = true;
  List<Json> tenants = const [], businesses = const [], profiles = const [];
  String? tenant, error;
  String role = 'viewer';
  bool isSuper = false, loading = true, _loggedLogin = false;
  int page = 0, request = 0, tick = 0;
  final networkAdd = ValueNotifier<int>(0);
  Map<String, int> profileScans = const {};
  int totalScans = 0;
  bool get seesNetwork => isSuper || staffRole == 'agent';
  int get tabCount => !canEdit ? 1 : 2 + (seesNetwork ? 1 : 0) + (isSuper ? 2 : 0);

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
    if (tenant == null) {
      _snack(tr('أنشئ مساحة عمل أولاً.'));
      return;
    }
    if (businesses.isEmpty) {
      _snack(tr('أضف نشاطاً تجارياً أولاً.'));
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
      _snack(tr('تم حفظ الشخص وأصبح في القائمة.'));
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

  /// "+" : new card (person), or — for admins and agents — a new app account
  /// (name + e-mail, the password is generated and sent on WhatsApp).
  Future<void> _plusMenu() async {
    if (!seesNetwork) return addPerson();
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.manage_accounts_rounded, color: AppColors.accent),
              title: Text(tr('حساب جديد للتطبيق (بالبريد الإلكتروني)'), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(tr('الاسم والبريد، وكلمة المرور تُنشأ تلقائياً وترسلها له')),
              onTap: () => Navigator.pop(context, 'account'),
            ),
            ListTile(
              leading: const Icon(Icons.badge_rounded, color: AppColors.primarySoft),
              title: Text(tr('بطاقة شخص جديدة (NFC / QR)'), style: const TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(context, 'card'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'card') return addPerson();
    setState(() => page = 2); // the Network tab
    await Future<void>.delayed(const Duration(milliseconds: 250));
    networkAdd.value++;
  }

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
  Future<void> deleteWorkspace() async {
    final current = tenants.where((t) => '${t['id']}' == tenant).firstOrNull;
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
      final r = await repo.client.rpc('nfc_delete_workspace', params: {'target': tenant});
      final res = r is Map ? r : const {};
      if (res['ok'] == true) {
        tenant = null;
        await load();
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
                hint: Text(tr('اختر مساحة عمل')),
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
            tooltip: tr('مساحة عمل جديدة'),
            onPressed: newTenant,
            icon: const Icon(Icons.add_box_outlined, size: 20),
          ),
          IconButton(
            tooltip: tr('حذف مساحة العمل'),
            onPressed: tenant == null ? null : deleteWorkspace,
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
          ),
          IconButton(
            tooltip: businesses.isEmpty ? tr('أضف نشاطاً تجارياً') : tr('النشاط التجاري'),
            onPressed: tenant == null || !canEdit ? null : () => businessForm(),
            icon: const Icon(Icons.storefront_outlined, size: 20),
          ),
        ],
      ),
    ),
  );

  Widget _body() {
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
        people,
        ShopsTab(
          key: ValueKey('shops-$tick-${tenant!}'),
          service: shops,
          network: network,
          tenant: tenant!,
          seeAll: seesNetwork,
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
            tooltip: tr('رابط مباشر على بطاقة NFC'),
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
            tooltip: tr('تحديث'),
            onPressed: loading ? null : () => load(),
            icon: const Icon(Icons.sync_rounded, size: 20),
          ),
          IconButton(
            tooltip: tr('تغيير كلمة المرور'),
            onPressed: changeMyPassword,
            icon: const Icon(Icons.key_rounded, size: 20),
          ),
          IconButton(
            tooltip: tr('تسجيل الخروج'),
            onPressed: signOut,
            icon: const Icon(Icons.logout_rounded, size: 20),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
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
          _workspaceBar(),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: canEdit && allowed && tenant != null
          ? NavigationBar(
              selectedIndex: page.clamp(0, tabCount - 1).toInt(),
              onDestinationSelected: (index) => setState(() => page = index),
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.people_alt_outlined),
                  selectedIcon: Icon(Icons.people_alt_rounded),
                  label: tr('الأشخاص'),
                ),
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront_rounded),
                  label: tr('المحلات'),
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
