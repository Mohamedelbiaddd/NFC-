import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/repository.dart';
import '../core/shops_service.dart';
import '../core/theme.dart';

/// Loyalty shops of the workspace. Field agents see the shops they created;
/// owners / admins see all of them. One simple form creates a shop.
class ShopsTab extends StatefulWidget {
  const ShopsTab({
    super.key,
    required this.service,
    required this.tenant,
    required this.currentUserId,
    required this.seeAll,
    required this.canDisable,
  });

  final ShopsService service;
  final String tenant;
  final String? currentUserId;
  final bool seeAll;
  final bool canDisable;

  @override
  State<ShopsTab> createState() => _ShopsTabState();
}

class _ShopsTabState extends State<ShopsTab> {
  List<Json> shops = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      var rows = await widget.service.overview(widget.tenant);
      if (!widget.seeAll) {
        rows = rows.where((s) => s['created_by'] == widget.currentUserId).toList();
      }
      if (mounted) setState(() => shops = rows);
    } catch (e) {
      if (mounted) setState(() => error = userError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String text, {bool bad = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: bad ? AppColors.danger : AppColors.success,
      ),
    );
  }

  Future<void> _form([Json? shop]) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ShopForm(service: widget.service, tenant: widget.tenant, shop: shop),
      ),
    );
    if (result != null) await load();
  }

  Future<void> _showAccess(Json shop, String password) async {
    final slug = '${shop['shop_slug']}';
    final link = ShopsService.ownerLink(slug);
    final message =
        'لوحة محلك «${shop['name']}»:\n$link\nكلمة المرور: $password\n\n'
        'افتح الرابط من متصفح هاتفك، ومنه يظهر الكود المتحرك وقائمة زبائنك.';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('دخول صاحب المحل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('أرسل هذه المعلومات لصاحب المحل:', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 10),
            SelectableText(link, textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.accent)),
            const SizedBox(height: 8),
            SelectableText(
              'كلمة المرور: $password',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'احفظ كلمة المرور الآن: لا تُعرض مرة أخرى، ويمكن إنشاء واحدة جديدة في أي وقت.',
              style: TextStyle(fontSize: 11.5, color: AppColors.warning),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (context.mounted) Navigator.pop(context);
              _snack('تم النسخ، أرسلها عبر واتساب');
            },
            child: const Text('نسخ الرسالة'),
          ),
          FilledButton(
            onPressed: () async {
              final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text('إرسال واتساب'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(Json shop) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('كلمة مرور جديدة؟'),
        content: const Text('ستتوقف كلمة المرور القديمة، ويخرج صاحب المحل من كل الأجهزة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إنشاء')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final password = ShopsService.randomPassword();
      await widget.service.setup(
        businessId: '${shop['id']}',
        slug: '${shop['shop_slug']}',
        goal: (shop['goal'] as num?)?.toInt() ?? 5,
        reward: '${shop['reward'] ?? ''}',
        password: password,
      );
      await load();
      if (mounted) await _showAccess(shop, password);
    } catch (e) {
      _snack(userError(e), bad: true);
    }
  }

  Future<void> _joinQr(Json shop) async {
    final link = ShopsService.customerLink('${shop['shop_slug']}');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('رابط الزبائن · ${shop['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: QrImageView(data: link, size: 220),
            ),
            const SizedBox(height: 10),
            SelectableText(link, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            const Text(
              'هذا الرمز ثابت: للانضمام ولكتابته على بطاقات NFC. أما تسجيل الزيارات '
              'فيتم بالكود المتحرك في لوحة المحل.',
              style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('نسخ الرابط'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(Json shop) async {
    final enabled = shop['loyalty_enabled'] == true;
    try {
      await widget.service.setDisabled('${shop['id']}', enabled);
      await load();
      _snack(enabled ? 'تم إيقاف المحل' : 'تم تفعيل المحل');
    } catch (e) {
      _snack(userError(e), bad: true);
    }
  }

  Widget _card(Json shop) {
    final (icon, label) = ShopsService.industries['${shop['industry']}'] ?? ('⭐', '');
    final enabled = shop['loyalty_enabled'] == true;
    final slug = '${shop['shop_slug']}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(icon, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${shop['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(
                        [label, if ('${shop['address'] ?? ''}'.isNotEmpty) '${shop['address']}'].join(' · '),
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                    switch (value) {
                      case 'owner':
                        await _resetPassword(shop);
                      case 'open':
                        await launchUrl(Uri.parse(ShopsService.ownerLink(slug)), mode: LaunchMode.externalApplication);
                      case 'join':
                        await _joinQr(shop);
                      case 'edit':
                        await _form(shop);
                      case 'toggle':
                        await _toggle(shop);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'owner', child: Text('🔑 رابط وكلمة مرور صاحب المحل')),
                    const PopupMenuItem(value: 'open', child: Text('🖥️ فتح لوحة المحل')),
                    const PopupMenuItem(value: 'join', child: Text('📱 رابط و QR الزبائن')),
                    const PopupMenuItem(value: 'edit', child: Text('✏️ تعديل المحل')),
                    if (widget.canDisable)
                      PopupMenuItem(value: 'toggle', child: Text(enabled ? '⛔ إيقاف المحل' : '✅ تفعيل المحل')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Pill('${shop['customers']} زبون', icon: Icons.people_alt_rounded),
                Pill('${shop['visits']} زيارة', color: AppColors.accent),
                Pill('${shop['visits_7d']} هذا الأسبوع', color: AppColors.accent),
                Pill('${shop['goal']}+1 · ${shop['reward']}', color: AppColors.success),
                if (!enabled) const Pill('موقوف', color: AppColors.danger),
                if (shop['has_password'] != true) const Pill('بدون كلمة مرور', color: AppColors.warning),
                if (widget.seeAll && '${shop['creator'] ?? ''}'.isNotEmpty)
                  Pill('أضافه: ${shop['creator']}', color: AppColors.muted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-shop',
        onPressed: () => _form(),
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('محل جديد'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(error!, style: const TextStyle(color: AppColors.danger)),
                    ),
                  if (shops.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Text(
                        'لا توجد محلات بعد.\nاضغط «محل جديد» وسجّل أول محل في دقيقة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, height: 1.8),
                      ),
                    ),
                  for (final shop in shops) _card(shop),
                ],
              ),
            ),
    );
  }
}

/// One-screen form to create or edit a shop. Pops with the business id.
class ShopForm extends StatefulWidget {
  const ShopForm({super.key, required this.service, required this.tenant, this.shop});

  final ShopsService service;
  final String tenant;
  final Json? shop;

  @override
  State<ShopForm> createState() => _ShopFormState();
}

class _ShopFormState extends State<ShopForm> {
  final formKey = GlobalKey<FormState>();
  late final name = TextEditingController(text: '${widget.shop?['name'] ?? ''}');
  late final phone = TextEditingController(text: '${widget.shop?['phone'] ?? ''}');
  late final address = TextEditingController(text: '${widget.shop?['address'] ?? ''}');
  late final hours = TextEditingController(text: '${widget.shop?['hours'] ?? ''}');
  late final reward = TextEditingController(text: '${widget.shop?['reward'] ?? 'زيارة مجانية'}');
  late String industry = '${widget.shop?['industry'] ?? 'barber'}';
  late int goal = (widget.shop?['goal'] as num?)?.toInt() ?? 5;
  bool saving = false;
  String? error;

  bool get editing => widget.shop != null;

  @override
  void dispose() {
    for (final c in [name, phone, address, hours, reward]) {
      c.dispose();
    }
    super.dispose();
  }

  String _defaultReward(String kind) => switch (kind) {
    'barber' => 'حلاقة مجانية',
    'beauty' => 'خدمة مجانية',
    'carwash' => 'غسلة مجانية',
    'bakery' => 'منتج مجاني',
    'cafe' => 'قهوة مجانية',
    'snack' => 'طلب مجاني',
    _ => 'زيارة مجانية',
  };

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      if (editing) {
        final id = '${widget.shop!['id']}';
        await widget.service.update(
          businessId: id,
          name: name.text.trim(),
          industry: industry,
          phone: phone.text,
          address: address.text,
          hours: hours.text,
        );
        await widget.service.setup(
          businessId: id,
          slug: '${widget.shop!['shop_slug']}',
          goal: goal,
          reward: reward.text.trim(),
        );
        if (mounted) Navigator.pop(context, id);
        return;
      }
      final created = await widget.service.create(
        tenant: widget.tenant,
        name: name.text.trim(),
        industry: industry,
        goal: goal,
        reward: reward.text.trim(),
        phone: phone.text,
        address: address.text,
        hours: hours.text,
      );
      if (!mounted) return;
      final password = created.password;
      final link = ShopsService.ownerLink(created.slug);
      final message =
          'لوحة محلك «${name.text.trim()}»:\n$link\nكلمة المرور: $password\n\n'
          'افتح الرابط من متصفح هاتفك، ومنه يظهر الكود المتحرك وقائمة زبائنك.';
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('✅ تم تسجيل المحل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('أرسل لصاحب المحل:', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 8),
              SelectableText(link, textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.accent)),
              const SizedBox(height: 8),
              SelectableText('كلمة المرور: $password', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'احفظها الآن: لا تُعرض مرة أخرى (يمكن إنشاء واحدة جديدة من قائمة ⋮).',
                style: TextStyle(fontSize: 11.5, color: AppColors.warning),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: message));
              },
              child: const Text('نسخ'),
            ),
            TextButton(
              onPressed: () async {
                await launchUrl(
                  Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('واتساب'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, created.id);
    } catch (e) {
      if (mounted) setState(() => error = userError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'تعديل المحل' : 'محل جديد')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            const Text('نوع النشاط', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in ShopsService.industries.entries)
                  ChoiceChip(
                    label: Text('${entry.value.$1} ${entry.value.$2}'),
                    selected: industry == entry.key,
                    onSelected: (_) => setState(() {
                      if (reward.text.trim().isEmpty || reward.text == _defaultReward(industry) || reward.text == 'زيارة مجانية') {
                        reward.text = _defaultReward(entry.key);
                      }
                      industry = entry.key;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: name,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'اسم المحل *', counterText: ''),
              validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب اسم المحل' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'الهاتف', counterText: ''),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: address,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'العنوان', counterText: ''),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: hours,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'أوقات العمل',
                hintText: 'مثال: كل يوم 9:00 - 21:00، الجمعة مغلق',
                counterText: '',
              ),
            ),
            const SizedBox(height: 18),
            const Text('بطاقة الولاء', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Expanded(child: Text('عدد الزيارات قبل الهدية')),
                IconButton(
                  onPressed: goal > 1 ? () => setState(() => goal--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$goal', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                IconButton(
                  onPressed: goal < 50 ? () => setState(() => goal++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            Text(
              'الزبون يجمع $goal ثم تكون الزيارة رقم ${goal + 1} مجانية.',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: reward,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'الهدية', counterText: ''),
              validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب الهدية' : null,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(saving ? 'جارٍ الحفظ…' : editing ? 'حفظ التعديلات' : 'تسجيل المحل'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
          ],
        ),
      ),
    );
  }
}
