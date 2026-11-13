import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'i18n.dart';
import 'theme.dart';

/// In-app update. CI publishes `version.json` ({"build": N}) next to the APK
/// on the "latest" release; this build knows its own number via APP_BUILD.
/// When a newer build exists a banner appears; one tap downloads it and
/// opens Android's install prompt.
class AppUpdate {
  static const build = int.fromEnvironment('APP_BUILD');
  static const _base =
      'https://github.com/Mohamedelbiaddd/NFC-/releases/download/latest';
  static const _channel = MethodChannel('tapmaroc/update');

  static Future<int?> latestBuild() async {
    // On the web (desktop browser) there is no APK to update: the page itself
    // is always the latest version.
    if (kIsWeb || !Platform.isAndroid || build == 0) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(
          '$_base/version.json?t=${DateTime.now().millisecondsSinceEpoch}'));
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final n = (jsonDecode(body) as Map)['build'];
      return n is int ? n : int.tryParse('$n');
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Downloads the APK, reporting 0..1 progress (or -1 when size is unknown).
  static Future<String> download(void Function(double) onProgress) async {
    final path = await _channel.invokeMethod<String>('apkPath');
    final file = File(path!);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse('$_base/nfc-studio.apk'));
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final total = res.contentLength;
      var got = 0;
      final sink = file.openWrite();
      await for (final chunk in res) {
        sink.add(chunk);
        got += chunk.length;
        onProgress(total > 0 ? got / total : -1);
      }
      await sink.close();
      return file.path;
    } finally {
      client.close(force: true);
    }
  }

  static Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;
  static Future<void> allowInstall() => _channel.invokeMethod('allowInstall');
  static Future<void> install(String path) =>
      _channel.invokeMethod('install', {'path': path});
}

/// Banner shown at the top of the home screen when an update is available.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> with WidgetsBindingObserver {
  int? latest;
  double? progress; // null = idle
  String? error;
  String? apkPath;
  DateTime _checked = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Back from the "allow installs" settings screen: continue installing.
    if (apkPath != null && progress == null) {
      _installReady();
    } else if (DateTime.now().difference(_checked) > const Duration(minutes: 30)) {
      _check();
    }
  }

  Future<void> _check() async {
    _checked = DateTime.now();
    final n = await AppUpdate.latestBuild();
    if (!mounted || n == null) return;
    setState(() => latest = n);
  }

  Future<void> _start() async {
    setState(() {
      progress = 0;
      error = null;
    });
    try {
      final path = await AppUpdate.download((p) {
        if (mounted) setState(() => progress = p);
      });
      apkPath = path;
      if (!mounted) return;
      setState(() => progress = null);
      await _installReady();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        progress = null;
        error = tr('تعذّر تنزيل التحديث. تحقق من الإنترنت وحاول مجدداً.');
      });
    }
  }

  Future<void> _installReady() async {
    final path = apkPath;
    if (path == null) return;
    if (!await AppUpdate.canInstall()) {
      if (!mounted) return;
      setState(() => error = tr('اسمح لـ TapMaroc بتثبيت التحديثات ثم ارجع إلى التطبيق.'));
      await AppUpdate.allowInstall();
      return;
    }
    try {
      await AppUpdate.install(path);
      if (mounted) setState(() => error = null);
    } catch (_) {
      if (mounted) setState(() => error = tr('تعذّر بدء التثبيت. حاول مجدداً.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = latest;
    if (n == null || n <= AppUpdate.build) return const SizedBox.shrink();
    final busy = progress != null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.system_update_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  busy
                      ? (progress! >= 0
                          ? trf('جارٍ تنزيل التحديث… {0}%', [(progress! * 100).round()])
                          : tr('جارٍ تنزيل التحديث…'))
                      : tr('تحديث جديد متوفر'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              if (!busy)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: apkPath != null ? _installReady : _start,
                  child: Text(apkPath != null ? tr('تثبيت') : tr('تحديث الآن')),
                ),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress! >= 0 ? progress : null,
              backgroundColor: Colors.white24,
              color: Colors.white,
              minHeight: 5,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error!, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
