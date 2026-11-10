import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'i18n.dart';

/// What the phone learned about a card it touched.
class NfcCardInfo {
  NfcCardInfo({
    required this.uid,
    required this.chip,
    required this.techs,
    this.ndefType,
    this.capacity,
    this.used,
    this.writable = false,
    this.formatable = false,
    this.canLock = false,
    this.passwordSupported = false,
    this.passwordProtected,
    this.content = const [],
  });

  final String uid;
  final String chip;
  final List<String> techs;
  final String? ndefType;
  final int? capacity; // bytes available for NDEF
  final int? used; // bytes the current content takes
  final bool writable;
  final bool formatable;
  final bool canLock;
  final bool passwordSupported;
  final bool? passwordProtected; // null: unknown
  final List<String> content;

  bool get hasNdef => ndefType != null;

  /// Can we use it: write links and have phones open them.
  bool get good => (hasNdef && writable) || formatable;

  /// Roughly how many link characters fit.
  int? get linkRoom => capacity == null ? null : (capacity! - 7).clamp(0, 100000);

  String get verdict {
    if (hasNdef && writable) return tr('✅ البطاقة صالحة وتعمل معنا: يمكن كتابتها وتفتح الرابط في أي هاتف.');
    if (hasNdef && !writable) return tr('🔒 البطاقة مقفلة نهائياً: تُقرأ فقط ولا يمكن تغييرها.');
    if (formatable) return tr('🆕 بطاقة جديدة غير مهيأة: ستُهيأ تلقائياً عند أول كتابة وتعمل معنا.');
    if (techs.any((t) => t.endsWith('MifareClassic'))) {
      return tr('⚠️ MIFARE Classic بدون تهيئة NDEF: هذا الهاتف لا يستطيع برمجتها. استعمل بطاقات NTAG213/215/216.');
    }
    return tr('❌ هذه البطاقة لا تدعم NDEF، لذلك لا تفتح الروابط في الهواتف. استعمل بطاقات NTAG21x.');
  }
}

/// NTAG21x / Ultralight EV1 chips we can password-protect, by GET_VERSION.
class _Chip {
  const _Chip(this.name, this.cfg0, this.userBytes);
  final String name;
  final int cfg0; // page of CFG0 (CFG1, PWD, PACK follow)
  final int userBytes;
}

/// All NFC card work on Android: inspect, write anything (link, WhatsApp,
/// phone, e-mail, text, contact), erase, password protect / change / remove
/// (NTAG21x and Ultralight EV1) and permanent lock.
class NfcService {
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Completer<dynamic>? _pending;
  bool _processing = false;

  // ---------- Messages ----------

  static const _uriPrefixes = <String, int>{
    'https://www.': 0x02, 'http://www.': 0x01, 'https://': 0x04, 'http://': 0x03,
    'tel:': 0x05, 'mailto:': 0x06,
  };

  static NdefRecord _record(int tnf, List<int> type, List<int> payload) => NdefRecord(
    typeNameFormat: TypeNameFormat.values[tnf],
    type: Uint8List.fromList(type),
    identifier: Uint8List(0),
    payload: Uint8List.fromList(payload),
  );

  /// Any URI: web link, tel:, mailto:, https://wa.me/...
  static NdefMessage uriMessage(String uri) {
    final u = Uri.tryParse(uri);
    if (u == null || u.scheme.isEmpty) throw FormatException(tr('الرابط غير صالح. مثال: https://example.com'));
    if ((u.scheme == 'https' || u.scheme == 'http') && u.host.isEmpty) {
      throw FormatException(tr('الرابط غير صالح. مثال: https://example.com'));
    }
    var code = 0x00;
    var rest = uri;
    for (final e in _uriPrefixes.entries) {
      if (uri.startsWith(e.key)) {
        code = e.value;
        rest = uri.substring(e.key.length);
        break;
      }
    }
    return NdefMessage(records: [_record(1, [0x55], [code, ...utf8.encode(rest)])]);
  }

  static NdefMessage textMessage(String text, {String language = 'ar'}) {
    final lang = ascii.encode(language);
    return NdefMessage(records: [_record(1, [0x54], [lang.length, ...lang, ...utf8.encode(text)])]);
  }

  /// A contact card (vCard): phones save it to contacts.
  static NdefMessage contactMessage({required String name, String? phone, String? email, String? org}) {
    String esc(String v) => v.replaceAll('\\', '\\\\').replaceAll(';', '\\;').replaceAll(',', '\\,');
    final card = StringBuffer()
      ..writeln('BEGIN:VCARD')
      ..writeln('VERSION:3.0')
      ..writeln('FN:${esc(name)}')
      ..writeln('N:${esc(name)};;;;');
    if (org != null && org.isNotEmpty) card.writeln('ORG:${esc(org)}');
    if (phone != null && phone.isNotEmpty) card.writeln('TEL;TYPE=CELL:$phone');
    if (email != null && email.isNotEmpty) card.writeln('EMAIL:$email');
    card.write('END:VCARD');
    return NdefMessage(records: [_record(2, ascii.encode('text/vcard'), utf8.encode(card.toString()))]);
  }

  /// "Erased" card: one empty record (phones show nothing).
  static NdefMessage emptyMessage() => NdefMessage(records: [_record(0, const [], const [])]);

  /// NDEF message bytes, for raw writes on password-protected chips.
  static Uint8List encode(NdefMessage m) {
    final out = <int>[];
    for (var i = 0; i < m.records.length; i++) {
      final r = m.records[i];
      final short = r.payload.length < 256;
      var header = r.typeNameFormat.index & 0x07;
      if (i == 0) header |= 0x80;
      if (i == m.records.length - 1) header |= 0x40;
      if (short) header |= 0x10;
      if (r.identifier.isNotEmpty) header |= 0x08;
      out
        ..add(header)
        ..add(r.type.length);
      if (short) {
        out.add(r.payload.length);
      } else {
        final n = r.payload.length;
        out.addAll([(n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF]);
      }
      if (r.identifier.isNotEmpty) out.add(r.identifier.length);
      out
        ..addAll(r.type)
        ..addAll(r.identifier)
        ..addAll(r.payload);
    }
    return Uint8List.fromList(out);
  }

  /// Human-readable lines for what a card holds.
  static List<String> describe(NdefMessage? m) {
    if (m == null || m.records.isEmpty) return [tr('(فارغة)')];
    final lines = <String>[];
    for (final r in m.records) {
      final tnf = r.typeNameFormat.index;
      final type = String.fromCharCodes(r.type);
      if (tnf == 0 || (r.payload.isEmpty && r.type.isEmpty)) {
        lines.add(tr('(فارغة)'));
      } else if (tnf == 1 && type == 'U' && r.payload.isNotEmpty) {
        final code = r.payload.first;
        final prefix = _uriPrefixes.entries.where((e) => e.value == code).map((e) => e.key).firstOrNull ?? '';
        lines.add('🔗 $prefix${utf8.decode(r.payload.sublist(1), allowMalformed: true)}');
      } else if (tnf == 1 && type == 'T' && r.payload.isNotEmpty) {
        final langLen = r.payload.first & 0x3F;
        lines.add('📝 ${utf8.decode(r.payload.sublist(1 + langLen), allowMalformed: true)}');
      } else if (tnf == 2 && type.toLowerCase().contains('vcard')) {
        final text = utf8.decode(r.payload, allowMalformed: true);
        final fn = RegExp(r'^FN:(.*)$', multiLine: true).firstMatch(text)?.group(1)?.trim();
        lines.add('👤 ${fn ?? tr('جهة اتصال')}');
      } else if (tnf == 2) {
        lines.add('📄 $type (${r.payload.length} B)');
      } else if (tnf == 4) {
        lines.add('🧩 $type (${r.payload.length} B)');
      } else {
        lines.add('❔ ${r.payload.length} B');
      }
    }
    return lines;
  }

  // ---------- Low level (NTAG21x / Ultralight EV1 over NFC-A) ----------

  static Uint8List _b(List<int> v) => Uint8List.fromList(v);

  static Future<_Chip?> _chip(NfcAAndroid a) async {
    try {
      final v = await a.transceive(_b([0x60]));
      if (v.length < 8 || v[1] != 0x04) return null; // NXP only
      final type = v[2], size = v[6];
      if (type == 0x04) {
        return switch (size) {
          0x0F => const _Chip('NTAG213', 0x29, 144),
          0x11 => const _Chip('NTAG215', 0x83, 504),
          0x13 => const _Chip('NTAG216', 0xE3, 888),
          _ => null,
        };
      }
      if (type == 0x03) {
        return switch (size) {
          0x0B => const _Chip('MIFARE Ultralight EV1 (48 B)', 0x10, 48),
          0x0E => const _Chip('MIFARE Ultralight EV1 (128 B)', 0x25, 128),
          _ => null,
        };
      }
    } catch (_) {/* not answering GET_VERSION */}
    return null;
  }

  /// PWD (4 bytes) and PACK (2 bytes) derived from the text password.
  static (List<int>, List<int>) _keys(String password) {
    final h = sha256.convert(utf8.encode('nfc-studio:${password.trim()}')).bytes;
    return (h.sublist(0, 4), h.sublist(4, 6));
  }

  static Future<void> _auth(NfcAAndroid a, String password) async {
    final (pwd, pack) = _keys(password);
    Uint8List r;
    try {
      r = await a.transceive(_b([0x1B, ...pwd]));
    } catch (_) {
      throw StateError(tr('كلمة سر البطاقة خاطئة. أبعد البطاقة ثم أعد المحاولة بكلمة السر الصحيحة.'));
    }
    if (r.length < 2 || r[0] != pack[0] || r[1] != pack[1]) {
      throw StateError(tr('كلمة سر البطاقة خاطئة. أبعد البطاقة ثم أعد المحاولة بكلمة السر الصحيحة.'));
    }
  }

  static Future<Uint8List> _read(NfcAAndroid a, int page) => a.transceive(_b([0x30, page]));
  static Future<void> _write(NfcAAndroid a, int page, List<int> four) async {
    await a.transceive(_b([0xA2, page, ...four]));
  }

  /// (AUTH0, ACCESS) or null when the config pages are not readable.
  static Future<(int, int)?> _config(NfcAAndroid a, _Chip chip) async {
    try {
      final r = await _read(a, chip.cfg0);
      return (r[3], r[4]);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _protect(NfcAAndroid a, _Chip chip, String password) async {
    final (pwd, pack) = _keys(password);
    final r = await _read(a, chip.cfg0);
    final cfg0 = r.sublist(0, 4), cfg1 = r.sublist(4, 8);
    await _write(a, chip.cfg0 + 2, pwd);
    await _write(a, chip.cfg0 + 3, [pack[0], pack[1], 0, 0]);
    // PROT = 0: the password guards writing only, every phone can still read.
    await _write(a, chip.cfg0 + 1, [cfg1[0] & 0x7F, cfg1[1], cfg1[2], cfg1[3]]);
    await _write(a, chip.cfg0, [cfg0[0], cfg0[1], cfg0[2], 0x04]); // from page 4 on
  }

  static Future<void> _unprotect(NfcAAndroid a, _Chip chip) async {
    final r = await _read(a, chip.cfg0);
    await _write(a, chip.cfg0, [r[0], r[1], r[2], 0xFF]);
  }

  /// Writes the message as an NDEF TLV from page 4 (after authentication).
  static Future<void> _rawWrite(NfcAAndroid a, _Chip chip, NdefMessage m) async {
    final msg = encode(m);
    final tlv = <int>[0x03, if (msg.length < 0xFF) msg.length else ...[0xFF, msg.length >> 8, msg.length & 0xFF], ...msg, 0xFE];
    if (tlv.length > chip.userBytes) {
      throw StateError(trf('مساحة الشريحة لا تكفي ({0}/{1})', [tlv.length, chip.userBytes]));
    }
    while (tlv.length % 4 != 0) {
      tlv.add(0);
    }
    for (var i = 0; i < tlv.length; i += 4) {
      await _write(a, 4 + i ~/ 4, tlv.sublist(i, i + 4));
    }
    final back = <int>[];
    for (var p = 4; back.length < tlv.length; p += 4) {
      back.addAll(await _read(a, p));
    }
    if (!listEquals(back.sublist(0, tlv.length), tlv)) {
      throw StateError(tr('فشل التحقق: محتوى البطاقة لا يطابق المطلوب'));
    }
  }

  static String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();

  static String _chipName(NfcTag tag, NfcTagAndroid? at, _Chip? chip, NdefAndroid? ndef) {
    if (chip != null) return chip.name;
    final techs = at?.techList ?? const <String>[];
    bool has(String t) => techs.any((x) => x.endsWith(t));
    if (has('MifareClassic')) return 'MIFARE Classic';
    if (has('MifareUltralight')) return 'MIFARE Ultralight / NTAG';
    if (has('IsoDep')) return 'ISO 14443-4 (DESFire…)';
    if (has('NfcV')) return 'ISO 15693 (ICODE…)';
    if (has('NfcF')) return 'FeliCa';
    return ndef?.type ?? tr('غير معروف');
  }

  // ---------- Session ----------

  Future<T> _session<T>(Future<T> Function(NfcTag tag) job) async {
    if (!supported) throw UnsupportedError(tr('برمجة NFC تتطلب هاتف Android داعماً.'));
    if (_pending != null) throw StateError(tr('جلسة NFC قيد التنفيذ'));
    if (await NfcManager.instance.checkAvailability() != NfcAvailability.enabled) {
      throw StateError(tr('فعّل NFC في إعدادات الهاتف'));
    }
    final c = Completer<T>();
    _pending = c;
    _processing = false;
    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (tag) async {
          if (_pending != c || _processing || c.isCompleted) return;
          _processing = true;
          try {
            final result = await job(tag);
            if (!c.isCompleted) c.complete(result);
          } catch (e, st) {
            if (!c.isCompleted) c.completeError(_friendly(e), st);
          }
        },
      );
      return await c.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException(tr('انتهى وقت الانتظار. قرّب البطاقة من ظهر الهاتف وأعد المحاولة.')),
      );
    } finally {
      _pending = null;
      await NfcManager.instance.stopSession();
    }
  }

  static Object _friendly(Object e) {
    final s = '$e';
    if (e is StateError || e is FormatException) return e;
    if (s.contains('TagLost') || s.contains('Tag was lost') || s.contains('tag_lost')) {
      return StateError(tr('ابتعدت البطاقة قبل انتهاء العملية. أبقِها ثابتة على ظهر الهاتف وأعد المحاولة.'));
    }
    if (s.contains('IOException') || s.contains('io_exception')) {
      return StateError(tr('رفضت البطاقة الكتابة. قد تكون محمية بكلمة سر: اكتب كلمة سرها ثم أعد المحاولة.'));
    }
    return e;
  }

  Future<void> cancel() async {
    final p = _pending;
    if (p == null) return;
    if (_processing) throw StateError(tr('عملية مادية بدأت؛ انتظر النتيجة ولا تبعد الشريحة'));
    if (!p.isCompleted) p.completeError(StateError(tr('أُلغيت جلسة الانتظار')));
  }

  // ---------- Operations ----------

  /// Reads everything about the card: chip, size, lock, password, content.
  Future<NfcCardInfo> inspect() => _session((tag) async {
    final at = NfcTagAndroid.from(tag);
    final ndef = NdefAndroid.from(tag);
    final a = NfcAAndroid.from(tag);
    NdefMessage? msg;
    if (ndef != null) {
      try {
        msg = await ndef.getNdefMessage();
      } catch (_) {
        msg = ndef.cachedNdefMessage;
      }
    }
    _Chip? chip;
    bool? protected;
    if (a != null) {
      chip = await _chip(a);
      if (chip != null) {
        final cfg = await _config(a, chip);
        protected = cfg == null ? true : cfg.$1 < 0xFF;
      }
    }
    return NfcCardInfo(
      uid: _hex(at?.id ?? Uint8List(0)),
      chip: _chipName(tag, at, chip, ndef),
      techs: at?.techList ?? const [],
      ndefType: ndef?.type,
      capacity: ndef?.maxSize ?? chip?.userBytes,
      used: msg?.byteLength,
      writable: ndef?.isWritable ?? false,
      formatable: ndef == null && NdefFormatableAndroid.from(tag) != null,
      canLock: ndef?.canMakeReadOnly ?? false,
      passwordSupported: chip != null,
      passwordProtected: protected,
      content: ndef == null ? const [] : describe(msg),
    );
  });

  /// Writes [message] (erase = [emptyMessage]). [password]: the card's
  /// current password if it is protected. [newPassword]: protect it after.
  Future<String> write(NdefMessage message, {String? password, String? newPassword}) => _session((tag) async {
    final hasPassword = password != null && password.isNotEmpty;
    if (hasPassword) {
      final a = NfcAAndroid.from(tag);
      final chip = a == null ? null : await _chip(a);
      if (a == null || chip == null) throw StateError(tr('هذه البطاقة لا تدعم كلمة السر (تدعمها NTAG213/215/216 وUltralight EV1).'));
      await _auth(a, password);
      await _rawWrite(a, chip, message);
      if (newPassword != null && newPassword.isNotEmpty) await _protect(a, chip, newPassword);
      return newPassword != null && newPassword.isNotEmpty
          ? tr('تمت الكتابة والتحقق، وتغيّرت كلمة سر البطاقة.')
          : tr('تمت الكتابة والتحقق. البطاقة ما زالت محمية بكلمة سرها.');
    }
    final ndef = NdefAndroid.from(tag);
    if (ndef == null) {
      final raw = NdefFormatableAndroid.from(tag);
      if (raw == null) throw StateError(tr('هذه البطاقة لا تدعم NDEF، لذلك لا تفتح الروابط في الهواتف. استعمل بطاقات NTAG21x.'));
      await raw.format(message);
    } else {
      if (!ndef.isWritable) throw StateError(tr('البطاقة مقفلة نهائياً للقراءة فقط'));
      if (message.byteLength > ndef.maxSize) {
        throw StateError(trf('مساحة الشريحة لا تكفي ({0}/{1})', [message.byteLength, ndef.maxSize]));
      }
      await ndef.writeNdefMessage(message);
      final actual = await ndef.getNdefMessage();
      if (actual != message) throw StateError(tr('فشل التحقق: محتوى البطاقة لا يطابق المطلوب'));
    }
    if (newPassword != null && newPassword.isNotEmpty) {
      final a = NfcAAndroid.from(tag);
      final chip = a == null ? null : await _chip(a);
      if (a == null || chip == null) {
        return tr('تمت الكتابة، لكن هذه البطاقة لا تدعم كلمة السر (تدعمها NTAG213/215/216).');
      }
      await _protect(a, chip, newPassword);
      return tr('تمت الكتابة والتحقق، ووُضعت كلمة سر على البطاقة 🔒');
    }
    return tr('تمت الكتابة والتحقق ✅');
  });

  /// Sets or changes the password ([current] when already protected).
  Future<String> setPassword(String newPassword, {String? current}) => _session((tag) async {
    final a = NfcAAndroid.from(tag);
    final chip = a == null ? null : await _chip(a);
    if (a == null || chip == null) throw StateError(tr('هذه البطاقة لا تدعم كلمة السر (تدعمها NTAG213/215/216 وUltralight EV1).'));
    if (current != null && current.isNotEmpty) {
      await _auth(a, current);
    } else {
      final cfg = await _config(a, chip);
      if (cfg == null || cfg.$1 < 0xFF) throw StateError(tr('البطاقة محمية بكلمة سر من قبل: اكتب كلمة سرها الحالية.'));
    }
    await _protect(a, chip, newPassword);
    return tr('وُضعت كلمة السر 🔒 لا يمكن تغيير البطاقة بعد الآن إلا بها.');
  });

  Future<String> removePassword(String current) => _session((tag) async {
    final a = NfcAAndroid.from(tag);
    final chip = a == null ? null : await _chip(a);
    if (a == null || chip == null) throw StateError(tr('هذه البطاقة لا تدعم كلمة السر (تدعمها NTAG213/215/216 وUltralight EV1).'));
    await _auth(a, current);
    await _unprotect(a, chip);
    return tr('أُزيلت كلمة السر 🔓 البطاقة مفتوحة للكتابة.');
  });

  /// Permanent read-only (cannot be undone).
  Future<String> lockForever() => _session((tag) async {
    final ndef = NdefAndroid.from(tag);
    if (ndef == null) throw StateError(tr('هذه البطاقة لا تدعم NDEF، لذلك لا تفتح الروابط في الهواتف. استعمل بطاقات NTAG21x.'));
    if (!ndef.isWritable) throw StateError(tr('الشريحة مقفلة بالفعل'));
    if (!ndef.canMakeReadOnly) throw StateError(tr('الشريحة لا تدعم القفل النهائي'));
    await ndef.makeReadOnly();
    return tr('قُفلت البطاقة نهائياً. لا يمكن تغييرها أبداً.');
  });

  /// Compatibility: write / verify / lock a link (used by older screens).
  Future<Map<String, dynamic>> perform(String action, String url) async {
    final expected = uriMessage(url);
    if (action == 'write') return {'action': 'written_verified', 'message': await write(expected)};
    if (action == 'lock') return {'action': 'locked', 'message': await lockForever()};
    final info = await inspect();
    final line = describe(expected).first;
    if (!info.content.contains(line)) throw StateError(tr('فشل التحقق: محتوى البطاقة لا يطابق المطلوب'));
    return {'action': 'verified', 'message': tr('تمت مطابقة الرابط على البطاقة.')};
  }
}
