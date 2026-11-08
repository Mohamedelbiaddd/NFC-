import 'package:flutter/material.dart';
import '../core/app_config.dart';
import '../core/repository.dart';
import '../core/nfc_service.dart';

class WriterScreen extends StatefulWidget {
  const WriterScreen({
    super.key,
    required this.repo,
    required this.tenant,
    required this.profileId,
  });
  final Repository repo;
  final String tenant, profileId;
  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen>
    with WidgetsBindingObserver {
  final nfc = NfcService();
  final domain = TextEditingController(text: AppConfig.profileBase);
  bool busy = false;
  String message = 'أدخل نطاقك الدائم وانشر الملف قبل برمجة البطاقة.';
  String? writtenUrl;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    domain.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && busy) {
      nfc.cancel().catchError((_) {});
    }
  }

  Future<void> act(String action) async {
    if (action == 'lock') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('قفل نهائي غير قابل للتراجع'),
          content: const Text(
            'ستُقفل الشريحة بعد مطابقة الرابط. قد لا يمكن إعادة برمجتها مطلقاً. تأكد من النطاق الدائم، وقرّب الشريحة التي تريد قفلها فقط.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('أوافق على القفل النهائي'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      busy = true;
      message = 'جارٍ التحقق من الملف…';
    });
    try {
      final p = await widget.repo.profile(widget.profileId, widget.tenant);
      if (p['published'] != true) {
        throw StateError('انشر الملف أولاً حتى يكون الرابط صالحاً للزوار');
      }
      final url = AppConfig.profileUrl(
        domain.text,
        p['custom_slug'] as String,
      ).toString();
      if (!mounted) return;
      setState(() {
        message = 'قرّب الشريحة الآن وأبقها ثابتة حتى ظهور النتيجة.';
        writtenUrl = url;
      });
      final result = await nfc.perform(action, url);
      var msg = result['message'] as String;
      try {
        await widget.repo.log(
          widget.tenant,
          widget.profileId,
          result['action'] as String,
        );
      } catch (_) {
        msg +=
            '\nنجحت العملية المادية، لكن تعذّر تسجيلها في الخادم. لا تكرر القفل.';
      }
      if (mounted) setState(() => message = msg);
    } catch (e) {
      if (mounted) setState(() => message = userError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('برمجة بطاقة NFC')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.contactless_rounded,
                size: 92,
                color: Color(0xFFB7A6FF),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: domain,
                enabled: !busy,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'النطاق الدائم HTTPS',
                  hintText: 'https://cards.example.com',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'يُكتب /p/custom-slug فقط؛ لا يُكتب UUID على البطاقة. يظل profileId داخلياً للتحقق من الصلاحية وتسجيل العملية.',
              ),
              const SizedBox(height: 20),
              if (writtenUrl != null)
                SelectableText(writtenUrl!, textDirection: TextDirection.ltr),
              const SizedBox(height: 20),
              Text(message),
              const SizedBox(height: 24),
              if (!NfcService.supported)
                const Text(
                  'هذه البيئة تدعم الإدارة فقط. افتح التطبيق على هاتف Android يدعم NFC للكتابة.',
                ),
              FilledButton.icon(
                onPressed: busy || !NfcService.supported
                    ? null
                    : () => act('write'),
                icon: const Icon(Icons.nfc),
                label: const Text('كتابة الرابط المخصص'),
              ),
              OutlinedButton(
                onPressed: busy || !NfcService.supported
                    ? null
                    : () => act('verify'),
                child: const Text('إعادة المسح للتحقق'),
              ),
              OutlinedButton(
                onPressed: busy || !NfcService.supported
                    ? null
                    : () => act('lock'),
                child: const Text('قفل makeReadOnly نهائياً'),
              ),
              if (busy)
                TextButton(
                  onPressed: () async {
                    try {
                      await nfc.cancel();
                    } catch (e) {
                      if (mounted) setState(() => message = userError(e));
                    }
                  },
                  child: const Text('إلغاء الانتظار (قبل بدء الكتابة)'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
