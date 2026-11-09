import 'package:flutter/material.dart';
import '../core/app_config.dart';
import '../core/repository.dart';
import '../core/nfc_service.dart';
import '../core/theme.dart';
import '../core/i18n.dart';

class WriterScreen extends StatefulWidget {
  const WriterScreen({
    super.key,
    required this.repo,
    required this.tenant,
    required this.profileId,
    this.profileName = '',
  });
  final Repository repo;
  final String tenant, profileId;
  final String profileName;
  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen>
    with WidgetsBindingObserver {
  final nfc = NfcService();
  final domain = TextEditingController(text: AppConfig.profileBase);
  bool busy = false;
  String message = tr('قرّب بطاقة NFC فارغة من الهاتف ثم اضغط «كتابة الرابط».');
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
        builder: (context) => AlertDialog(
          title: Text(tr('قفل نهائي غير قابل للتراجع')),
          content: Text(
            tr('ستُقفل الشريحة بعد مطابقة الرابط. قد لا يمكن إعادة برمجتها مطلقاً. تأكد من النطاق الدائم، وقرّب الشريحة التي تريد قفلها فقط.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('إلغاء')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('أوافق على القفل النهائي')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      busy = true;
      message = tr('جارٍ التحقق من الملف…');
    });
    try {
      final p = await widget.repo.profile(widget.profileId, widget.tenant);
      if (p['published'] != true) {
        throw StateError(tr('انشر البطاقة أولاً حتى يكون الرابط صالحاً للزوار'));
      }
      final url = AppConfig.profileUrl(
        domain.text,
        p['custom_slug'] as String,
      );
      await nfc.perform(action, url.toString());
      if (!mounted) return;
      setState(() {
        message = switch (action) {
          'write' => tr('تمت كتابة البطاقة. اختبرها بلمس الهاتف بها.'),
          'verify' => tr('الرابط على البطاقة مطابق للمطلوب.'),
          _ => tr('تم قفل البطاقة نهائياً.'),
        };
        if (action != 'lock') writtenUrl = url.toString();
      });
    } catch (e) {
      if (mounted) setState(() => message = userError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = NfcService.supported;
    final needsDomain = AppConfig.profileBase.isEmpty;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('ربط بطاقة NFC'), style: TextStyle(fontSize: 18)),
              if (widget.profileName.isNotEmpty)
                Text(
                  widget.profileName,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                SurfaceCard(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primarySoft],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 26,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Icon(
                          busy ? Icons.nfc : Icons.contactless_rounded,
                          size: 46,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        busy ? tr('في انتظار البطاقة…') : tr('جاهز للكتابة'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (writtenUrl != null) ...[
                  const SizedBox(height: 12),
                  SurfaceCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            writtenUrl!,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (needsDomain) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: domain,
                    enabled: !busy,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: tr('النطاق الدائم HTTPS'),
                      hintText: 'https://cards.example.com',
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (!supported)
                  SurfaceCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr('كتابة البطاقات تحتاج هاتف Android يدعم NFC. يمكنك هنا إدارة البيانات ورمز QR فقط.'),
                            style: TextStyle(fontSize: 12.5, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                FilledButton.icon(
                  onPressed: busy || !supported ? null : () => act('write'),
                  icon: Icon(busy ? Icons.hourglass_top_rounded : Icons.nfc),
                  label: Text(busy ? tr('جارٍ العمل…') : tr('كتابة الرابط على البطاقة')),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy || !supported
                            ? null
                            : () => act('verify'),
                        icon: const Icon(Icons.verified_outlined, size: 18),
                        label: Text(tr('التحقق')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy || !supported ? null : () => act('lock'),
                        icon: const Icon(Icons.lock_outline_rounded, size: 18),
                        label: Text(tr('قفل نهائي')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: BorderSide(
                            color: AppColors.danger.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                    child: Text(tr('إلغاء الانتظار (قبل بدء الكتابة)')),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  tr('يُكتب المسار /p/custom-slug فقط، ولا يُكتب UUID على البطاقة.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
