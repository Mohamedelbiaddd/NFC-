import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'i18n.dart';

/// This phone as the server knows it: a random id kept in the app's private
/// storage, the model, and the signs used to refuse a modified app.
class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.model,
    required this.platform,
    required this.os,
    this.abi = '',
    this.cert = '',
    this.rooted = false,
    this.emulator = false,
    this.debuggable = false,
  });

  final String id, model, platform, os, abi, cert;
  final bool rooted, emulator, debuggable;

  Map<String, String> toJson() => {
    'id': id,
    'model': model,
    'platform': platform,
    'os': os,
    'app': '${const int.fromEnvironment('APP_BUILD')}',
  };
}

/// One phone per staff account (see migration staff_invites_devices).
class DeviceGuard {
  /// SHA-256 of the release signing certificate, set by CI.
  static const expectedCert = String.fromEnvironment('CERT_SHA256');
  static const _channel = MethodChannel('tapmaroc/device');
  static const _idKey = 'device_id_v1';
  static DeviceInfo? _info;

  static Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_idKey);
    if (id == null || id.length < 16) {
      final r = Random.secure();
      id = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
      await prefs.setString(_idKey, id);
    }
    return id;
  }

  static Future<DeviceInfo> info() async {
    if (_info != null) return _info!;
    final id = await _deviceId();
    if (kIsWeb) {
      return _info = DeviceInfo(id: id, model: tr('متصفح الحاسوب'), platform: 'web', os: 'web');
    }
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('info') ?? const {};
      return _info = DeviceInfo(
        id: id,
        model: '${m['model'] ?? 'Android'}',
        platform: 'android',
        os: '${m['os'] ?? ''}',
        abi: '${m['abi'] ?? ''}',
        cert: '${m['cert'] ?? ''}',
        rooted: m['rooted'] == true,
        emulator: m['emulator'] == true,
        debuggable: m['debuggable'] == true,
      );
    } catch (_) {
      return _info = DeviceInfo(id: id, model: 'Android', platform: 'android', os: '');
    }
  }

  /// Why this app must not run, or null. Only the official signed build is
  /// checked (CI sets CERT_SHA256); a developer build runs anywhere.
  static Future<String?> integrityProblem() async {
    if (kIsWeb || !kReleaseMode || expectedCert.isEmpty) return null;
    final d = await info();
    if (d.cert.isNotEmpty && d.cert.toLowerCase() != expectedCert.toLowerCase()) {
      return tr('هذه نسخة معدّلة من التطبيق. نزّل التطبيق الأصلي من رابط الدعوة.');
    }
    if (d.debuggable) return tr('هذه نسخة غير صالحة من التطبيق.');
    if (d.rooted) return tr('لا يعمل TapMaroc على هاتف مكسور الحماية (Root). استعمل هاتفاً عادياً.');
    if (d.emulator) return tr('لا يعمل TapMaroc على المحاكي. استعمل هاتفاً حقيقياً.');
    return null;
  }

  /// Tells the server which phone this session runs on. Returns
  /// {status: active | pending | ended | blocked, active_model?}.
  static Future<Map<String, dynamic>> hello(SupabaseClient client) async {
    final d = await info();
    final value = await client.rpc('nfc_device_hello', params: {
      'p_device': d.id,
      'p_model': d.model,
      'p_platform': d.platform,
      'p_os': d.os,
      'p_app': '${const int.fromEnvironment('APP_BUILD')}',
      'p_cert': d.cert,
    });
    return value is Map ? Map<String, dynamic>.from(value) : {'status': 'error'};
  }

  /// tapmaroc://activate?t=... that opened the app, if any.
  static Future<String?> initialLink() async {
    if (kIsWeb) return null;
    try {
      return await _channel.invokeMethod<String>('initialLink');
    } catch (_) {
      return null;
    }
  }

  /// Links that arrive while the app is open.
  static void onLink(void Function(String link) handler) {
    if (kIsWeb) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'link' && call.arguments is String) handler(call.arguments as String);
    });
  }

  /// The invitation token inside a tapmaroc:// or https://tapmaroc.com/app/ link.
  static String? tokenOf(String link) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null) return null;
    final t = uri.queryParameters['t'] ??
        (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'app' ? uri.pathSegments[1] : null);
    return t != null && RegExp(r'^[A-Za-z0-9]{30,64}$').hasMatch(t) ? t : null;
  }
}
