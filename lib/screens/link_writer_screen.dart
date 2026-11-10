import 'package:flutter/material.dart';
import 'package:ndef_record/ndef_record.dart';
import '../core/i18n.dart';

import '../core/nfc_service.dart';
import '../core/repository.dart';
import '../core/theme.dart';

/// NFC tools: read a card (is it good for us?), write anything on it (link,
/// WhatsApp, phone, e-mail, text, contact), erase it, protect it with a
/// password (set / change / remove) or lock it forever.
class LinkWriterScreen extends StatefulWidget {
  const LinkWriterScreen({super.key, required this.repo, this.tenant, this.initialUrl, this.title});

  final Repository repo;
  final String? tenant;

  /// Pre-filled link, e.g. a shop's loyalty page.
  final String? initialUrl;
  final String? title;

  @override
  State<LinkWriterScreen> createState() => _LinkWriterScreenState();
}

enum _Kind { link, whatsapp, phone, email, text, contact }

class _LinkWriterScreenState extends State<LinkWriterScreen> {
  final nfc = NfcService();
  final value = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final cardPassword = TextEditingController();
  final newPassword = TextEditingController();
  _Kind kind = _Kind.link;
  bool busy = false;
  bool protectAfter = false;
  String message = tr('اختر ما تريد فعله، ثم قرّب البطاقة من ظهر الهاتف.');
  bool? lastOk;
  NfcCardInfo? info;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) value.text = widget.initialUrl!;
  }

  @override
  void dispose() {
    for (final c in [value, name, phone, email, cardPassword, newPassword]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _currentPassword => cardPassword.text.trim().isEmpty ? null : cardPassword.text.trim();

  /// The NDEF message for the chosen kind, or an error text.
  (NdefMessage?, String?) _message() {
    final v = value.text.trim();
    String digits(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');
    try {
      switch (kind) {
        case _Kind.link:
          var link = v;
          if (link.isEmpty) return (null, tr('اكتب الرابط.'));
          if (!link.contains('://')) link = 'https://$link';
          final u = Uri.tryParse(link);
          if (u == null || u.host.isEmpty || !u.host.contains('.') || RegExp(r'\s').hasMatch(link)) {
            return (null, tr('الرابط غير صالح. مثال: https://example.com'));
          }
          return (NfcService.uriMessage(link), null);
        case _Kind.whatsapp:
          final n = digits(v).replaceFirst(RegExp(r'^\+'), '').replaceFirst(RegExp(r'^00'), '');
          if (n.length < 8) return (null, tr('اكتب رقم واتساب مع رمز الدولة، مثال: 212612345678'));
          return (NfcService.uriMessage('https://wa.me/$n'), null);
        case _Kind.phone:
          final n = digits(v);
          if (n.length < 6) return (null, tr('اكتب رقم الهاتف.'));
          return (NfcService.uriMessage('tel:$n'), null);
        case _Kind.email:
          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) return (null, tr('البريد الإلكتروني غير صحيح'));
          return (NfcService.uriMessage('mailto:$v'), null);
        case _Kind.text:
          if (v.isEmpty) return (null, tr('اكتب النص.'));
          return (NfcService.textMessage(v), null);
        case _Kind.contact:
          if (name.text.trim().isEmpty) return (null, tr('اكتب الاسم.'));
          return (
            NfcService.contactMessage(
              name: name.text.trim(),
              phone: digits(phone.text),
              email: email.text.trim(),
            ),
            null,
          );
      }
    } on FormatException catch (e) {
      return (null, e.message);
    }
  }

  Future<void> _run(Future<String> Function() job, {String? log}) async {
    setState(() {
      busy = true;
      lastOk = null;
      message = tr('قرّب البطاقة من ظهر الهاتف وأبقِها ثابتة…');
    });
    try {
      final text = await job();
      if (!mounted) return;
      setState(() {
        message = text;
        lastOk = true;
      });
      if (log != null && widget.tenant != null) {
        await widget.repo.logEvent(widget.tenant!, 'link_written', subject: log);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          message = userError(e);
          lastOk = false;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _inspect() => _run(() async {
    final i = await nfc.inspect();
    if (mounted) setState(() => info = i);
    return i.verdict;
  });

  Future<void> _write() async {
    final (m, error) = _message();
    if (m == null) {
      setState(() {
        message = error ?? '';
        lastOk = false;
      });
      return;
    }
    String? newPass;
    if (protectAfter) {
      newPass = newPassword.text.trim();
      if (newPass.length < 4) {
        setState(() {
          message = tr('كلمة سر البطاقة 4 أحرف أو أرقام على الأقل.');
          lastOk = false;
        });
        return;
      }
    }
    await _run(
      () => nfc.write(m, password: _currentPassword, newPassword: newPass),
      log: NfcService.describe(m).first,
    );
  }

  Future<bool> _confirm(String title, String body, {bool danger = true}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('إلغاء'))),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('متابعة')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _erase() async {
    if (!await _confirm(tr('مسح محتوى البطاقة؟'), tr('سيُحذف كل ما على البطاقة وتصبح فارغة وجاهزة لكتابة جديدة.'))) return;
    await _run(() async {
      await nfc.write(NfcService.emptyMessage(), password: _currentPassword);
      return tr('تم مسح البطاقة، أصبحت فارغة ✅');
    });
  }

  Future<String?> _askPassword(String title, {bool twice = true}) async {
    final a = TextEditingController(), b = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: a, obscureText: true, decoration: InputDecoration(labelText: tr('كلمة السر'))),
              if (twice)
                TextField(controller: b, obscureText: true, decoration: InputDecoration(labelText: tr('أعد كتابتها'))),
              if (error != null) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: const TextStyle(color: AppColors.danger)),
              ),
              const SizedBox(height: 8),
              Text(
                tr('احفظها جيداً: بدونها لا يمكن تغيير البطاقة أبداً.'),
                style: const TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('إلغاء'))),
            FilledButton(
              onPressed: () {
                final p = a.text.trim();
                if (p.length < 4) return setLocal(() => error = tr('كلمة سر البطاقة 4 أحرف أو أرقام على الأقل.'));
                if (twice && p != b.text.trim()) return setLocal(() => error = tr('كلمتا السر غير متطابقتين'));
                Navigator.pop(context, p);
              },
              child: Text(tr('متابعة')),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<void> _setPassword() async {
    final p = await _askPassword(_currentPassword == null ? tr('🔒 وضع كلمة سر للبطاقة') : tr('🔑 كلمة سر جديدة للبطاقة'));
    if (p == null) return;
    await _run(() => nfc.setPassword(p, current: _currentPassword));
  }

  Future<void> _removePassword() async {
    final current = _currentPassword ?? await _askPassword(tr('كلمة السر الحالية للبطاقة'), twice: false);
    if (current == null) return;
    await _run(() => nfc.removePassword(current));
  }

  Future<void> _lock() async {
    if (!await _confirm(
      tr('قفل البطاقة نهائياً؟'),
      tr('بعد القفل لا يمكن تغيير البطاقة أو مسحها أبداً، حتى بكلمة سر. استعمله فقط للبطاقات النهائية.'),
    )) return;
    await _run(() => nfc.lockForever());
  }

  Widget _kindChips() {
    final items = <_Kind, (IconData, String)>{
      _Kind.link: (Icons.link_rounded, tr('رابط')),
      _Kind.whatsapp: (Icons.chat_rounded, tr('واتساب')),
      _Kind.phone: (Icons.call_rounded, tr('هاتف')),
      _Kind.email: (Icons.mail_rounded, tr('بريد')),
      _Kind.text: (Icons.notes_rounded, tr('نص')),
      _Kind.contact: (Icons.contact_page_rounded, tr('جهة اتصال')),
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in items.entries)
          ChoiceChip(
            avatar: Icon(e.value.$1, size: 16),
            label: Text(e.value.$2),
            selected: kind == e.key,
            onSelected: busy ? null : (_) => setState(() => kind = e.key),
          ),
      ],
    );
  }

  Widget _input() {
    if (kind == _Kind.contact) {
      return Column(
        children: [
          TextField(controller: name, enabled: !busy, decoration: InputDecoration(labelText: tr('الاسم'), prefixIcon: const Icon(Icons.person))),
          const SizedBox(height: 8),
          TextField(controller: phone, enabled: !busy, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('الهاتف'), prefixIcon: const Icon(Icons.call))),
          const SizedBox(height: 8),
          TextField(controller: email, enabled: !busy, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: tr('البريد الإلكتروني'), prefixIcon: const Icon(Icons.mail))),
        ],
      );
    }
    final (label, hint, type, ltr) = switch (kind) {
      _Kind.link => (tr('الرابط (موقع، إنستغرام، خرائط…)'), 'https://example.com', TextInputType.url, true),
      _Kind.whatsapp => (tr('رقم واتساب مع رمز الدولة'), '212612345678', TextInputType.phone, true),
      _Kind.phone => (tr('رقم الهاتف'), '+212612345678', TextInputType.phone, true),
      _Kind.email => (tr('البريد الإلكتروني'), 'name@example.com', TextInputType.emailAddress, true),
      _ => (tr('النص'), '', TextInputType.multiline, false),
    };
    return TextField(
      controller: value,
      enabled: !busy,
      keyboardType: type,
      maxLines: kind == _Kind.text ? 4 : 1,
      textDirection: ltr ? TextDirection.ltr : null,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _infoCard(NfcCardInfo i) {
    Widget row(String k, String v, [Color? c]) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 12.5))),
          Expanded(child: Text(v, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: c))),
        ],
      ),
    );
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('📋 معلومات البطاقة'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (i.good ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(i.verdict, style: TextStyle(color: i.good ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          row(tr('نوع الشريحة'), i.chip),
          row(tr('الرقم التسلسلي'), i.uid),
          if (i.capacity != null)
            row(tr('المساحة'), trf('{0} بايت (≈ {1} حرفاً للرابط)', [i.capacity, i.linkRoom])),
          if (i.used != null) row(tr('المستعمل'), trf('{0} بايت', [i.used])),
          row(tr('الكتابة'), i.hasNdef ? (i.writable ? tr('مفتوحة ✅') : tr('مقفلة نهائياً 🔒')) : (i.formatable ? tr('تحتاج تهيئة (تلقائية)') : tr('غير مدعومة ❌')),
              i.hasNdef && !i.writable ? AppColors.danger : null),
          row(tr('كلمة السر'), !i.passwordSupported
              ? tr('غير مدعومة في هذه الشريحة')
              : i.passwordProtected == true ? tr('محمية 🔐') : tr('بدون كلمة سر'),
              i.passwordProtected == true ? AppColors.warning : null),
          if (i.hasNdef && i.writable) row(tr('القفل النهائي'), i.canLock ? tr('ممكن') : tr('غير ممكن')),
          if (i.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(tr('المحتوى الحالي:'), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            for (final line in i.content)
              SelectableText(line, textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.accent)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supported = NfcService.supported;
    final enabled = !busy && supported;
    final statusColor = lastOk == null ? AppColors.muted : lastOk! ? AppColors.success : AppColors.danger;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title ?? tr('📡 أدوات NFC'))),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                SurfaceCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Icon(busy ? Icons.nfc_rounded : (lastOk == false ? Icons.error_outline_rounded : Icons.nfc_rounded),
                          size: 46, color: busy ? AppColors.accent : statusColor == AppColors.muted ? AppColors.accent : statusColor),
                      const SizedBox(height: 10),
                      Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, height: 1.6, color: statusColor)),
                      if (busy) ...[
                        const SizedBox(height: 10),
                        const LinearProgressIndicator(),
                        TextButton(
                          onPressed: () async {
                            try {
                              await nfc.cancel();
                            } catch (e) {
                              if (mounted) setState(() => message = userError(e));
                            }
                          },
                          child: Text(tr('إلغاء الانتظار')),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!supported)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(tr('برمجة البطاقات تحتاج هاتف Android يدعم NFC.'), style: const TextStyle(color: AppColors.warning)),
                  ),
                const SizedBox(height: 14),
                // 1. Inspect
                OutlinedButton.icon(
                  onPressed: enabled ? _inspect : null,
                  icon: const Icon(Icons.search_rounded),
                  label: Text(tr('🔍 فحص البطاقة: هل تصلح وتعمل معنا؟')),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
                if (info != null) ...[const SizedBox(height: 12), _infoCard(info!)],
                const SizedBox(height: 22),
                // 2. Write
                SectionTitle(tr('✍️ كتابة على البطاقة')),
                _kindChips(),
                const SizedBox(height: 12),
                _input(),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: protectAfter,
                  onChanged: busy ? null : (v) => setState(() => protectAfter = v),
                  title: Text(tr('🔒 هل تريد وضع كلمة سر بعد الكتابة؟')),
                  subtitle: Text(tr('لا يستطيع أحد تغيير البطاقة إلا بكلمة السر. القراءة تبقى عادية لكل الهواتف.'),
                      style: const TextStyle(fontSize: 11.5)),
                ),
                if (protectAfter)
                  TextField(
                    controller: newPassword,
                    enabled: !busy,
                    obscureText: true,
                    decoration: InputDecoration(labelText: tr('كلمة سر البطاقة (4 أحرف على الأقل)'), prefixIcon: const Icon(Icons.lock_rounded)),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: enabled ? _write : null,
                  icon: const Icon(Icons.nfc_rounded),
                  label: Text(busy ? tr('جارٍ العمل…') : tr('كتابة على البطاقة')),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                ),
                const SizedBox(height: 22),
                // 3. Card password & management
                SectionTitle(tr('🔐 كلمة السر والإدارة')),
                TextField(
                  controller: cardPassword,
                  enabled: !busy,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: tr('كلمة سر البطاقة الحالية (إذا كانت محمية)'),
                    helperText: tr('تُستعمل للكتابة والمسح وتغيير كلمة السر على البطاقات المحمية.'),
                    prefixIcon: const Icon(Icons.key_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: enabled ? _setPassword : null,
                      icon: const Icon(Icons.lock_rounded, size: 18),
                      label: Text(tr('وضع / تغيير كلمة السر')),
                    ),
                    OutlinedButton.icon(
                      onPressed: enabled ? _removePassword : null,
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: Text(tr('إزالة كلمة السر')),
                    ),
                    OutlinedButton.icon(
                      onPressed: enabled ? _erase : null,
                      icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                      label: Text(tr('مسح البطاقة')),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: enabled ? _lock : null,
                      icon: const Icon(Icons.block_rounded, size: 18),
                      label: Text(tr('قفل نهائي')),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  tr('💡 أفضل البطاقات: NTAG213 (روابط قصيرة)، NTAG215 وNTAG216 (مساحة أكبر). كلها تعمل مع كل الهواتف وتدعم كلمة السر.'),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
