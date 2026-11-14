import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n.dart';
import '../core/network_service.dart';
import '../core/repository.dart';
import '../core/theme.dart';

/// After creating an account or sending a new link: the invitation link and
/// code (no password), e-mailed or ready to share by WhatsApp.
Future<void> showInviteResult(BuildContext context, String name, Json result) async {
  final link = '${result['link']}';
  final code = '${result['code']}';
  final email = '${result['email'] ?? ''}';
  final emailed = result['emailed'] == true;
  final message = trf(
    'مرحباً {0} 👋\nتمت إضافتك إلى فريق TapMaroc.\n1) افتح هذا الرابط من هاتفك الأندرويد ونزّل التطبيق:\n{1}\n2) فعّل حسابك واختر كلمة مرورك. رمز التفعيل: {2}\n\nالرابط صالح 24 ساعة ولمرة واحدة، والحساب يعمل على هاتف واحد فقط.\n\n⚠️ تنبيه هام: إذا دخل شخص آخر إلى التطبيق بهذه الدعوة قبلك فلن تستطيع الدخول، لأن الحساب يعمل على الهاتف الذي دخل أولاً ويجب أن يوافق على هاتفك. تواصل معنا: واتساب +39 329 558 6046 · contact@tapmaroc.com',
    [name, link, code],
  );
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(emailed ? tr('✅ أُرسلت الدعوة بالبريد') : tr('✅ الدعوة جاهزة')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              emailed
                  ? trf('وصلت رسالة إلى {0} فيها رابط تحميل التطبيق ورمز التفعيل.', [email])
                  : tr('أرسل هذه الدعوة إلى الشخص (واتساب أو نسخ). سيختار كلمة مروره بنفسه عند التفعيل.'),
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            Text(tr('رمز التفعيل'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            SelectableText(
              code,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3),
            ),
            const SizedBox(height: 8),
            SelectableText(link, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            const SizedBox(height: 10),
            Text(
              tr('⏱ الرابط صالح 24 ساعة ولمرة واحدة. إن لم يُفعَّل الحساب في الوقت أرسل رابطاً جديداً.'),
              style: TextStyle(fontSize: 11.5, color: AppColors.warning),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: message)),
          child: Text(tr('نسخ')),
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'),
            mode: LaunchMode.externalApplication,
          ),
          child: Text(tr('واتساب')),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('تم'))),
      ],
    ),
  );
}

String inviteStateLabel(String? state) => switch (state) {
  'activated' => tr('مفعّل'),
  'sent' => tr('الدعوة مرسلة، لم يفعّل بعد'),
  'expired' => tr('انتهت الدعوة دون تفعيل'),
  'revoked' => tr('الدعوة ملغاة'),
  _ => tr('بدون دعوة'),
};

Color inviteStateColor(String? state) => switch (state) {
  'activated' => AppColors.success,
  'sent' => AppColors.warning,
  'expired' || 'revoked' => AppColors.danger,
  _ => AppColors.muted,
};

/// Account security of one member: invitation, phone(s), and the actions
/// (new link, approve a waiting phone, allow a new phone).
class SecurityPanel extends StatefulWidget {
  const SecurityPanel({super.key, required this.network, required this.userId, required this.name});

  final NetworkService network;
  final String userId;
  final String name;

  @override
  State<SecurityPanel> createState() => _SecurityPanelState();
}

class _SecurityPanelState extends State<SecurityPanel> {
  Json? data;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.network.security(widget.userId);
      if (mounted) setState(() => data = d);
    } catch (_) {
      if (mounted) setState(() => data = {});
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => busy = true);
    try {
      await action();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is NetworkException ? e.message : userError(e)), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _invite() async {
    setState(() => busy = true);
    try {
      final r = await widget.network.invite(widget.userId);
      await _load();
      if (mounted) await showInviteResult(context, widget.name, r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is NetworkException ? e.message : userError(e)), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('السماح بهاتف جديد؟')),
        content: Text(tr('سيُغلق الحساب على الهاتف الحالي فوراً، وأول هاتف يسجّل الدخول بعد ذلك يصبح هاتف الحساب.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('تأكيد'))),
        ],
      ),
    );
    if (ok == true) await _run(() => widget.network.resetDevice(widget.userId), tr('تم. يمكنه الآن الدخول من هاتف جديد.'));
  }

  IconData _icon(String? platform) => platform == 'web' ? Icons.computer_rounded : Icons.smartphone_rounded;

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d == null) return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
    final invite = d['invite'] is Map ? Map<String, dynamic>.from(d['invite'] as Map) : null;
    final devices = (d['devices'] is List ? d['devices'] as List : const []).whereType<Map>().toList();
    final state = invite?['state'] as String?;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.shield_outlined, size: 20, color: AppColors.primarySoft),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('الدعوة والهاتف'), style: const TextStyle(fontWeight: FontWeight.w800))),
            if (busy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Pill(inviteStateLabel(state), color: inviteStateColor(state)),
            if (invite != null && (invite['downloads'] as num? ?? 0) > 0)
              Pill(trf('حمّل التطبيق {0} مرة', [invite['downloads']]), color: AppColors.accent),
            if (invite != null && invite['activated_at'] != null)
              Pill(trf('فعّل {0}', [relativeTime(DateTime.tryParse('${invite['activated_at']}'))]), color: AppColors.muted),
            if (invite != null && state == 'sent')
              Pill(trf('ينتهي {0}', [shortDate(DateTime.tryParse('${invite['expires_at']}'))]), color: AppColors.muted),
            if (invite?['email_status'] != null)
              Pill('${invite!['email_status']}' == 'sent' ? tr('📧 وصل البريد') : tr('📧 لم يُرسل البريد'),
                  color: '${invite['email_status']}' == 'sent' ? AppColors.success : AppColors.danger),
          ]),
          const SizedBox(height: 8),
          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(tr('لم يسجّل الدخول من أي هاتف بعد.'), style: const TextStyle(color: AppColors.muted)),
            ),
          for (final dev in devices)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _icon(dev['platform'] as String?),
                color: switch ('${dev['status']}') {
                  'active' => AppColors.success,
                  'pending' => AppColors.warning,
                  _ => AppColors.muted,
                },
              ),
              title: Text('${dev['model'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                [
                  switch ('${dev['status']}') {
                    'active' => tr('هاتف الحساب'),
                    'pending' => tr('ينتظر الموافقة'),
                    _ => tr('محجوب'),
                  },
                  '${dev['os'] ?? ''}',
                  trf('آخر نشاط: {0}', [relativeTime(DateTime.tryParse('${dev['last_seen']}'))]),
                ].where((s) => s.isNotEmpty).join(' · '),
                style: const TextStyle(fontSize: 11.5),
              ),
              trailing: '${dev['status']}' == 'pending'
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: tr('رفض'),
                        onPressed: busy ? null : () => _run(() => widget.network.decideDevice('${dev['id']}', false), tr('تم الرفض')),
                        icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                      ),
                      IconButton(
                        tooltip: tr('موافقة'),
                        onPressed: busy
                            ? null
                            : () => _run(() => widget.network.decideDevice('${dev['id']}', true), tr('أصبح هذا الهاتف هاتف الحساب')),
                        icon: const Icon(Icons.check_rounded, color: AppColors.success),
                      ),
                    ])
                  : null,
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonalIcon(
              onPressed: busy ? null : _invite,
              icon: const Icon(Icons.forward_to_inbox_rounded),
              label: Text(tr('إرسال رابط تفعيل جديد')),
            ),
            if (devices.any((x) => x['status'] == 'active'))
              OutlinedButton.icon(
                onPressed: busy ? null : _reset,
                icon: const Icon(Icons.phonelink_setup_rounded),
                label: Text(tr('السماح بهاتف جديد')),
              ),
          ]),
        ],
      ),
    );
  }
}
