import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/i18n.dart';

import 'dart:async';

import '../core/network_service.dart';
import '../core/repository.dart';
import '../core/shops_service.dart';
import '../core/theme.dart';
import 'link_writer_screen.dart';
import 'network_tab.dart' show statusColor, editNotice;

/// Loyalty shops of the workspace. Field agents see the shops they created;
/// owners / admins see all of them. One simple form creates a shop.
class ShopsTab extends StatefulWidget {
  const ShopsTab({
    super.key,
    required this.service,
    required this.network,
    required this.tenant,
    required this.seeAll,
    this.onlyCreators,
    this.allowCreate = true,
  });

  final ShopsService service;
  final NetworkService network;
  final String tenant;
  final bool seeAll;

  /// When set, only shops registered by these accounts (a member's network).
  final Set<String>? onlyCreators;
  final bool allowCreate;

  @override
  State<ShopsTab> createState() => _ShopsTabState();
}

class _ShopsTabState extends State<ShopsTab> {
  List<Json> shops = const [];
  bool loading = true;
  String? error;
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

  // Shops of the caller's network only (strict isolation is enforced by the
  // database: an agent never receives another agent's shops).
  Future<void> load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final only = widget.onlyCreators;
      final rows = (await widget.network.shops())
          .where((s) => only == null || only.contains('${s['created_by']}'))
          .toList();
      if (mounted) setState(() => shops = rows);
    } catch (e) {
      if (mounted && !quiet) setState(() => error = userError(e));
    } finally {
      if (mounted && !quiet) setState(() => loading = false);
    }
  }

  Future<void> _togglePaid(Json shop) async {
    final id = '${shop['id']}';
    try {
      if (shop['status'] == 'paid') {
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('إلغاء آخر دفعة؟')),
            content: Text(tr('سيرجع تاريخ الاشتراك كما كان قبل آخر علامة ✓.')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('لا'))),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('نعم'))),
            ],
          ),
        );
        if (ok != true) return;
        await widget.network.undoPayment('shop', id);
      } else {
        await widget.network.markPaid('shop', id);
        _snack(trf('✓ تم تسجيل دفع شهر لـ {0}', [shop['name']]));
      }
      await load(quiet: true);
    } catch (e) {
      _snack(userError(e), bad: true);
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
        shopAccessMessage('${shop['name']}', slug, password);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('دخول صاحب المحل')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('🔗 رابط الولاء (للزبائن وبطاقة NFC):'), style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 4),
            SelectableText(ShopsService.customerLink(slug), textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.success)),
            const SizedBox(height: 12),
            Text(tr('🔑 لوحة صاحب المحل:'), style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 4),
            SelectableText(link, textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.accent)),
            const SizedBox(height: 8),
            SelectableText(
              trf('كلمة المرور: {0}', [password]),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              tr('احفظ كلمة المرور الآن: لا تُعرض مرة أخرى، ويمكن إنشاء واحدة جديدة في أي وقت.'),
              style: TextStyle(fontSize: 11.5, color: AppColors.warning),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (context.mounted) Navigator.pop(context);
              _snack(tr('تم النسخ، أرسلها عبر واتساب'));
            },
            child: Text(tr('نسخ الرسالة')),
          ),
          FilledButton(
            onPressed: () async {
              final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Text(tr('إرسال واتساب')),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(Json shop) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('كلمة مرور جديدة؟')),
        content: Text(tr('ستتوقف كلمة المرور القديمة، ويخرج صاحب المحل من كل الأجهزة.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('إنشاء'))),
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
        title: Text(trf('رابط الزبائن · {0}', [shop['name']])),
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
            Text(
              tr('هذا الرمز ثابت: للانضمام ولكتابته على بطاقات NFC. أما تسجيل الزيارات فيتم بالكود المتحرك في لوحة المحل.'),
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
            child: Text(tr('نسخ الرابط')),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(Json shop) async {
    final suspended = shop['suspended'] == true;
    try {
      await widget.network.setShopSuspended('${shop['id']}', !suspended);
      await load(quiet: true);
      _snack(suspended ? tr('تم تفعيل المحل وروابطه') : tr('تم إيقاف المحل وكل روابطه'));
    } catch (e) {
      _snack(userError(e), bad: true);
    }
  }

  Future<void> _writeNfc(Json shop) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => LinkWriterScreen(
        repo: Repository(widget.service.client),
        tenant: widget.tenant,
        initialUrl: ShopsService.customerLink('${shop['shop_slug']}'),
        title: trf('بطاقة NFC · {0}', [shop['name']]),
      ),
    ),
  );

  Future<void> _notice(Json shop) async {
    try {
      final changed = await editNotice(context, widget.network, 'shop', '${shop['id']}', '${shop['name']}', shop['notice'] as String?);
      if (changed) {
        await load(quiet: true);
        _snack(tr('تم'));
      }
    } catch (e) {
      _snack(userError(e), bad: true);
    }
  }

  /// Everything about one shop on one sheet: loyalty link, NFC, owner
  /// password, edit, notice and suspension.
  Future<void> _details(Json shop) async {
    final slug = '${shop['shop_slug']}';
    final loyalty = ShopsService.customerLink(slug);
    final enabled = shop['suspended'] != true;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        Widget tile(String value, IconData icon, String title, [String? sub, Color? color]) => ListTile(
          leading: Icon(icon, color: color ?? AppColors.primarySoft),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          subtitle: sub == null ? null : Text(sub, style: const TextStyle(fontSize: 11.5)),
          onTap: () => Navigator.pop(context, value),
        );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text('${shop['name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('🔗 رابط الولاء'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      SelectableText(loyalty, textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.success)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context, 'copy'),
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: Text(tr('نسخ')),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context, 'join'),
                            icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                            label: Text(tr('QR')),
                          ),
                          FilledButton.icon(
                            onPressed: () => Navigator.pop(context, 'nfc'),
                            icon: const Icon(Icons.nfc_rounded, size: 16),
                            label: Text(tr('كتابة على NFC')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                tile('owner', Icons.key_rounded, tr('🔑 كلمة مرور جديدة لصاحب المحل'),
                    tr('تنشئ كلمة مرور وترسلها مع الروابط عبر واتساب؛ وهو يغيّرها بنفسه بعد الدخول.'),
                    shop['reset_requested'] == true ? AppColors.danger : null),
                tile('open', Icons.dashboard_rounded, tr('🖥️ فتح لوحة المحل'), ShopsService.ownerLink(slug)),
                tile('edit', Icons.edit_rounded, tr('✏️ تعديل المعلومات'), tr('الاسم، النوع، الهاتف، العنوان، الأوقات، الزيارات والهدية، الموقع')),
                tile('notice', Icons.mark_email_unread_rounded, shop['notice'] == null ? tr('📩 إرسال تنبيه دفع') : tr('📩 تعديل / إزالة التنبيه')),
                tile('toggle', enabled ? Icons.block_rounded : Icons.check_circle_rounded,
                    enabled ? tr('⛔ إيقاف المحل وروابطه') : tr('✅ تفعيل المحل'), null,
                    enabled ? AppColors.danger : AppColors.success),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: loyalty));
        _snack(tr('تم نسخ الرابط'));
      case 'join':
        await _joinQr(shop);
      case 'nfc':
        await _writeNfc(shop);
      case 'owner':
        await _resetPassword(shop);
      case 'open':
        await launchUrl(Uri.parse(ShopsService.ownerLink(slug)), mode: LaunchMode.externalApplication);
      case 'edit':
        await _form(shop);
      case 'notice':
        await _notice(shop);
      case 'toggle':
        await _toggle(shop);
    }
  }

  Widget _card(Json shop) {
    final (icon, label) = ShopsService.industries['${shop['industry']}'] ?? ('⭐', '');
    final enabled = shop['suspended'] != true;
    final slug = '${shop['shop_slug']}';
    final status = '${shop['status']}';
    final color = statusColor(status);
    final paidUntil = DateTime.tryParse('${shop['paid_until'] ?? ''}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _details(shop),
        child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1.4),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Checkbox(
                  value: status == 'paid',
                  activeColor: AppColors.success,
                  onChanged: (_) => _togglePaid(shop),
                ),
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
                      Text(
                        '${shop['name']}',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color == AppColors.muted ? null : color),
                      ),
                      Text(
                        [label, if ('${shop['address'] ?? ''}'.isNotEmpty) '${shop['address']}'].join(' · '),
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr('كل ميزات المحل'),
                  onPressed: () => _details(shop),
                  icon: const Icon(Icons.edit_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Pill(
                  status == 'paid' && paidUntil != null
                      ? trf('مدفوع حتى {0}', [shortDate(paidUntil)])
                      : status == 'expired' && paidUntil != null
                      ? trf('انتهى {0}', [shortDate(paidUntil)])
                      : statusLabel(status),
                  color: color,
                ),
                Pill(trf('{0} زبون', [shop['customers']]), icon: Icons.people_alt_rounded),
                Pill(trf('{0} زيارة', [shop['visits']]), color: AppColors.accent),
                Pill(trf('{0} هذا الأسبوع', [shop['visits_7d']]), color: AppColors.accent),
                Pill('${shop['goal']}+1 · ${shop['reward']}', color: AppColors.success),
                if (!enabled) Pill(tr('موقوف'), color: AppColors.danger),
                if (shop['notice'] != null) Pill(tr('📩 تنبيه مُرسل'), color: AppColors.warning),
                if (shop['reset_requested'] == true)
                  Pill(tr('🔑 يطلب كلمة مرور جديدة'), color: AppColors.danger),
                if (shop['has_password'] != true) Pill(tr('بدون كلمة مرور'), color: AppColors.warning),
                if (widget.seeAll && '${shop['creator'] ?? ''}'.isNotEmpty)
                  Pill(trf('أضافه: {0}', [shop['creator']]), color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _joinQr(shop),
                    icon: const Icon(Icons.link_rounded, size: 16),
                    label: Text(tr('رابط الولاء'), overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _writeNfc(shop),
                    icon: const Icon(Icons.nfc_rounded, size: 16),
                    label: Text(tr('NFC'), overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _resetPassword(shop),
                    icon: const Icon(Icons.key_rounded, size: 16),
                    label: Text(tr('كلمة المرور'), overflow: TextOverflow.ellipsis),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: !widget.allowCreate
          ? null
          : FloatingActionButton.extended(
              heroTag: 'add-shop',
              onPressed: () => _form(),
              icon: const Icon(Icons.add_business_rounded),
              label: Text(tr('محل جديد')),
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
                    Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Text(
                        tr('لا توجد محلات بعد.\nاضغط «محل جديد» وسجّل أول محل في دقيقة.'),
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

/// One-screen form to create or edit a shop. Pops with the shop slug.
class ShopForm extends StatefulWidget {
  const ShopForm({super.key, required this.service, required this.tenant, this.shop, this.initialName});

  final ShopsService service;
  final String tenant;
  final Json? shop;

  /// Pre-filled shop name when created from a loyalty card form.
  final String? initialName;

  @override
  State<ShopForm> createState() => _ShopFormState();
}

class _ShopFormState extends State<ShopForm> {
  final formKey = GlobalKey<FormState>();
  late final name = TextEditingController(text: '${widget.shop?['name'] ?? widget.initialName ?? ''}');
  late final phone = TextEditingController(text: '${widget.shop?['phone'] ?? ''}');
  late final address = TextEditingController(text: '${widget.shop?['address'] ?? ''}');
  late final hours = TextEditingController(text: '${widget.shop?['hours'] ?? ''}');
  late final reward = TextEditingController(text: trf('{0}', [widget.shop?['reward'] ?? tr('زيارة مجانية')]));
  late String industry = '${widget.shop?['industry'] ?? 'barber'}';
  late int goal = (widget.shop?['goal'] as num?)?.toInt() ?? 5;
  late int radius = (widget.shop?['radius_m'] as num?)?.toInt() ?? 200;
  late final location = TextEditingController(
    text: widget.shop?['latitude'] == null ? '' : '${widget.shop!['latitude']}, ${widget.shop!['longitude']}',
  );
  bool saving = false;
  String? error;

  bool get editing => widget.shop != null;

  @override
  void dispose() {
    for (final c in [name, phone, address, hours, reward, location]) {
      c.dispose();
    }
    super.dispose();
  }

  String _defaultReward(String kind) => switch (kind) {
    'barber' => tr('حلاقة مجانية'),
    'beauty' => tr('خدمة مجانية'),
    'carwash' => tr('غسلة مجانية'),
    'bakery' => tr('منتج مجاني'),
    'cafe' => tr('قهوة مجانية'),
    'snack' => tr('طلب مجاني'),
    _ => tr('زيارة مجانية'),
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
          location: ShopsService.parseLocation(location.text),
          radius: radius,
        );
        await widget.service.setup(
          businessId: id,
          slug: '${widget.shop!['shop_slug']}',
          goal: goal,
          reward: reward.text.trim(),
        );
        if (mounted) Navigator.pop(context, '${widget.shop!['shop_slug']}');
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
        location: ShopsService.parseLocation(location.text),
        radius: radius,
      );
      if (!mounted) return;
      final password = created.password;
      final link = ShopsService.ownerLink(created.slug);
      final message =
          shopAccessMessage(name.text.trim(), created.slug, password);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(tr('✅ تم تسجيل المحل')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('🔗 رابط الولاء (للزبائن وبطاقة NFC):'), style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 4),
              SelectableText(ShopsService.customerLink(created.slug), textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.success)),
              const SizedBox(height: 12),
              Text(tr('🔑 لوحة صاحب المحل:'), style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 4),
              SelectableText(link, textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.accent)),
              const SizedBox(height: 8),
              SelectableText(trf('كلمة المرور: {0}', [password]), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                tr('أرسلها الآن: لا تُعرض مرة أخرى. صاحب المحل يغيّرها بنفسه من «الإعدادات» في لوحته، ويمكنك إنشاء واحدة جديدة بالضغط على المحل.'),
                style: TextStyle(fontSize: 11.5, color: AppColors.warning),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: message));
              },
              child: Text(tr('نسخ')),
            ),
            TextButton(
              onPressed: () async {
                await launchUrl(
                  Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Text(tr('واتساب')),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('تم'))),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, created.slug);
    } catch (e) {
      if (mounted) setState(() => error = userError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editing ? tr('تعديل المحل') : tr('محل جديد'))),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            Text(tr('نوع النشاط'), style: TextStyle(fontWeight: FontWeight.w700)),
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
                      if (reward.text.trim().isEmpty || reward.text == _defaultReward(industry) || reward.text == tr('زيارة مجانية')) {
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
              decoration: InputDecoration(labelText: tr('اسم المحل *'), counterText: ''),
              validator: (v) => (v ?? '').trim().isEmpty ? tr('اكتب اسم المحل') : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              maxLength: 40,
              decoration: InputDecoration(labelText: tr('الهاتف'), counterText: ''),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: address,
              maxLength: 200,
              decoration: InputDecoration(labelText: tr('العنوان'), counterText: ''),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: hours,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: tr('أوقات العمل'),
                hintText: tr('مثال: كل يوم 9:00 - 21:00، الجمعة مغلق'),
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: location,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: tr('📍 موقع المحل (اختياري)'),
                hintText: tr('الصق رابط Google Maps أو 33.5731, -7.5898'),
              ),
              validator: (v) => (v ?? '').trim().isEmpty || ShopsService.parseLocation(v!) != null
                  ? null
                  : tr('لم أفهم الموقع: الصق رابط خرائط فيه الإحداثيات'),
            ),
            Row(
              children: [
                Expanded(child: Text(tr('نطاق التذكير (متر)'))),
                IconButton(
                  onPressed: radius > 50 ? () => setState(() => radius -= 50) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$radius', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                IconButton(
                  onPressed: radius < 1000 ? () => setState(() => radius += 50) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            Text(
              tr('صاحب المحل يستطيع أيضاً تحديد الموقع بضغطة من لوحته وهو داخل المحل.'),
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Text(tr('بطاقة الولاء'), style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text(tr('عدد الزيارات قبل الهدية'))),
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
              trf('الزبون يجمع {0} ثم تكون الزيارة رقم {1} مجانية.', [goal, goal + 1]),
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: reward,
              maxLength: 120,
              decoration: InputDecoration(labelText: tr('الهدية'), counterText: ''),
              validator: (v) => (v ?? '').trim().isEmpty ? tr('اكتب الهدية') : null,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(saving ? tr('جارٍ الحفظ…') : editing ? tr('حفظ التعديلات') : tr('تسجيل المحل')),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
          ],
        ),
      ),
    );
  }
}

/// WhatsApp message for the shop owner: loyalty link, dashboard and password.
String shopAccessMessage(String name, String slug, String password) => trf(
  'محل «{0}» جاهز ✅\n\n🔗 رابط الولاء لزبائنك (ضعه على بطاقة NFC أو QR):\n{1}\n\n🔑 لوحة المحل:\n{2}\nكلمة المرور: {3}\n\nبعد الدخول غيّر كلمة المرور من «الإعدادات».',
  [name, ShopsService.customerLink(slug), ShopsService.ownerLink(slug), password],
);
