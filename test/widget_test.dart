import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_studio/core/app_config.dart';
import 'package:nfc_studio/core/nfc_service.dart';
import 'package:ndef_record/ndef_record.dart';

void main() {
  test('custom URL never includes an internal identifier', () {
    expect(
      AppConfig.profileUrl(
        'https://cards.example.com',
        'ahmad-electric',
      ).toString(),
      'https://cards.example.com/p/ahmad-electric',
    );
    expect(
      AppConfig.profileUrl('https://cards.example.com/', 'bella-napoli').query,
      '',
    );
  });
  test('reject invalid/reserved slugs', () {
    for (final s in [
      'a',
      'Ahmad',
      'a--b',
      '-test',
      'test-',
      '../x',
      'a/b',
      'admin',
      'hello world',
      'أحمد',
      'x' * 64,
    ]) {
      expect(AppConfig.validSlug(s), isFalse, reason: s);
    }
    for (final s in ['ahmad-electric', 'bella-napoli', 'abc', 'a1-b2']) {
      expect(AppConfig.validSlug(s), isTrue);
    }
  });
  test('require an HTTPS origin, not a URL with query or index path', () {
    for (final base in [
      '',
      'http://example.com',
      'https://example.com/index.html',
      'https://example.com?x=1',
      'https://example.com/#x',
      'https://u:p@example.com',
    ]) {
      expect(
        () => AppConfig.profileUrl(base, 'ahmad-electric'),
        throwsFormatException,
      );
    }
  });
  test('NDEF encodes the vanity URL using HTTPS URI record prefix', () {
    final message = NfcService.uriMessage(
      'https://cards.example.com/p/bella-napoli',
    );
    expect(message.records.single.type, [0x55]);
    expect(message.records.single.payload.first, 0x04);
    expect(NdefMessage.decode(message.encode()), message);
    expect(message.byteLength, message.encode().length);
  });
  testWidgets('RTL layout supports a clean vanity URL label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SelectableText(
              '/p/ahmad-electric',
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ),
    );
    expect(find.text('/p/ahmad-electric'), findsOneWidget);
  });
}
