import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

class NfcService {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Completer<Map<String, dynamic>>? _pending;
  bool _processing = false;
  static NdefMessage uriMessage(String url) {
    final u = Uri.parse(url);
    if ((u.scheme != 'https' && u.scheme != 'http') || u.host.isEmpty) {
      throw const FormatException('الرابط يجب أن يبدأ بـ https://');
    }
    // NDEF URI prefix codes: 0x04 = "https://", 0x03 = "http://".
    final https = u.scheme == 'https';
    final rest = url.substring(https ? 8 : 7);
    return NdefMessage(
      records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          type: Uint8List.fromList([0x55]),
          identifier: Uint8List(0),
          payload: Uint8List.fromList([https ? 0x04 : 0x03, ...utf8.encode(rest)]),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> perform(String action, String url) async {
    if (!supported) {
      throw UnsupportedError('برمجة NFC تتطلب هاتف Android داعماً.');
    }
    if (!{'write', 'verify', 'lock'}.contains(action)) {
      throw ArgumentError('Invalid operation');
    }
    if (_pending != null) throw StateError('جلسة NFC قيد التنفيذ');
    if (await NfcManager.instance.checkAvailability() !=
        NfcAvailability.enabled) {
      throw StateError('فعّل NFC في إعدادات الهاتف');
    }
    final c = Completer<Map<String, dynamic>>();
    _pending = c;
    _processing = false;
    final expected = uriMessage(url);
    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (tag) async {
          if (_pending != c || _processing || c.isCompleted) return;
          _processing = true;
          try {
            final ndef = NdefAndroid.from(tag);
            if (ndef == null) {
              final raw = NdefFormatableAndroid.from(tag);
              if (action != 'write' || raw == null) {
                throw StateError('الشريحة لا تدعم العملية أو تحتاج تهيئة NDEF');
              }
              await raw.format(expected);
              if (!c.isCompleted) {
                c.complete({
                  'action': 'formatted_unverified',
                  'message':
                      'تمت التهيئة والكتابة. أبعد البطاقة ثم استخدم التحقق بإعادة المسح قبل القفل.',
                });
              }
            } else {
              if (action == 'write') {
                if (!ndef.isWritable) {
                  throw StateError('البطاقة مقفلة للقراءة فقط');
                }
                if (expected.byteLength > ndef.maxSize) {
                  throw StateError(
                    'مساحة الشريحة لا تكفي للرابط (${expected.byteLength}/${ndef.maxSize})',
                  );
                }
                await ndef.writeNdefMessage(expected);
              }
              final actual = await ndef.getNdefMessage();
              if (actual != expected) {
                throw StateError(
                  'فشل التحقق: محتوى البطاقة لا يطابق الرابط المطلوب',
                );
              }
              if (action == 'lock') {
                if (!ndef.isWritable) {
                  throw StateError(
                    'الشريحة مقفلة بالفعل؛ لم يتم إجراء قفل جديد',
                  );
                }
                if (!ndef.canMakeReadOnly) {
                  throw StateError('الشريحة لا تدعم makeReadOnly');
                }
                await ndef.makeReadOnly();
              }
              if (!c.isCompleted) {
                c.complete({
                  'action': action == 'write'
                      ? 'written_verified'
                      : action == 'lock'
                      ? 'locked'
                      : 'verified',
                  'message': action == 'lock'
                      ? 'تم القفل نهائياً بعد مطابقة الرابط.'
                      : 'تمت مطابقة رابط الاسم المخصص على الشريحة.',
                });
              }
            }
          } catch (e, st) {
            if (!c.isCompleted) c.completeError(e, st);
          }
        },
      );
      return await c.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException(
          'انتهت الجلسة. إن بدأت الكتابة فأعد المسح للتحقق من حالة البطاقة؛ لا يُفترض إلغاء التغيير المادي.',
        ),
      );
    } finally {
      _pending = null;
      await NfcManager.instance.stopSession();
    }
  }

  Future<void> cancel() async {
    final p = _pending;
    if (p == null) return;
    if (_processing) {
      throw StateError('عملية مادية بدأت؛ انتظر النتيجة ولا تبعد الشريحة');
    }
    if (!p.isCompleted) p.completeError(StateError('أُلغيت جلسة الانتظار'));
  }
}
