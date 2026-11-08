import 'package:flutter/material.dart';
import '../core/i18n.dart';

import '../core/nfc_service.dart';
import '../core/repository.dart';
import '../core/theme.dart';

/// Writes any web address directly on an NFC card (no profile page): scanning
/// the card opens that website straight away.
class LinkWriterScreen extends StatefulWidget {
  const LinkWriterScreen({super.key, required this.repo, this.tenant});

  final Repository repo;
  final String? tenant;

  @override
  State<LinkWriterScreen> createState() => _LinkWriterScreenState();
}

class _LinkWriterScreenState extends State<LinkWriterScreen> {
  final nfc = NfcService();
  final url = TextEditingController();
  bool busy = false;
  String message = tr('اكتب الرابط، ثم اضغط «كتابة» وقرّب البطاقة من الهاتف.');
  String? written;

  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  /// Adds https:// when the operator typed only "example.com".
  String? _normalized() {
    var text = url.text.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'https://$text';
    final u = Uri.tryParse(text);
    if (u == null ||
        (u.scheme != 'https' && u.scheme != 'http') ||
        u.host.isEmpty ||
        !u.host.contains('.') ||
        RegExp(r'\s').hasMatch(text)) {
      return null;
    }
    return text;
  }

  Future<void> act(String action) async {
    final link = _normalized();
    if (link == null) {
      setState(() => message = tr('الرابط غير صالح. مثال: https://example.com'));
      return;
    }
    setState(() {
      busy = true;
      message = tr('قرّب البطاقة من ظهر الهاتف…');
    });
    try {
      await nfc.perform(action, link);
      if (!mounted) return;
      setState(() {
        written = link;
        message = action == 'write'
            ? tr('تمت كتابة الرابط. عند مسح البطاقة سيفتح الموقع مباشرة.')
            : tr('الرابط على البطاقة مطابق.');
      });
      if (action == 'write' && widget.tenant != null) {
        await widget.repo.logEvent(widget.tenant!, 'link_written', subject: link);
      }
    } catch (e) {
      if (mounted) setState(() => message = userError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = NfcService.supported;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(tr('رابط مباشر على البطاقة'))),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                SurfaceCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        busy ? Icons.nfc : Icons.link_rounded,
                        size: 48,
                        color: AppColors.accent,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: AppColors.muted,
                        ),
                      ),
                      if (written != null) ...[
                        const SizedBox(height: 10),
                        SelectableText(
                          written!,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: url,
                  enabled: !busy,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: tr('الرابط (موقع، إنستغرام، واتساب، خرائط…)'),
                    hintText: 'https://example.com',
                    prefixIcon: Icon(Icons.public),
                  ),
                ),
                const SizedBox(height: 16),
                if (!supported)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      tr('كتابة البطاقات تحتاج هاتف Android يدعم NFC.'),
                      style: TextStyle(color: AppColors.warning),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: busy || !supported ? null : () => act('write'),
                  icon: const Icon(Icons.nfc),
                  label: Text(busy ? tr('جارٍ العمل…') : tr('كتابة الرابط على البطاقة')),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: busy || !supported ? null : () => act('verify'),
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: Text(tr('التحقق من البطاقة')),
                ),
                if (busy) ...[
                  const SizedBox(height: 10),
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
        ),
      ),
    );
  }
}
