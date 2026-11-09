import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_studio/core/storage_service.dart';

Uint8List bytes(List<int> head) =>
    Uint8List.fromList([...head, ...List<int>.filled(32, 0)]);

void main() {
  test('image type is detected from magic bytes, not the file name', () {
    final png = decodeImagePayload(
      bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
    );
    expect(png?.extension, 'png');
    expect(png?.contentType, 'image/png');

    final jpeg = decodeImagePayload(bytes([0xFF, 0xD8, 0xFF, 0xE0]));
    expect(jpeg?.extension, 'jpg');
    expect(jpeg?.contentType, 'image/jpeg');

    final webp = decodeImagePayload(
      bytes([0x52, 0x49, 0x46, 0x46, 0x20, 0, 0, 0, 0x57, 0x45, 0x42, 0x50]),
    );
    expect(webp?.extension, 'webp');
    expect(webp?.contentType, 'image/webp');
  });

  test('unsupported or truncated payloads are rejected', () {
    expect(decodeImagePayload(bytes([0x47, 0x49, 0x46, 0x38])), isNull);
    expect(decodeImagePayload(Uint8List(0)), isNull);
    expect(decodeImagePayload(Uint8List.fromList([0x89, 0x50])), isNull);
  });

  test('upload failures are explained in Arabic', () {
    expect(
      imageUploadError(Exception('Bucket not found')),
      contains('profile-images'),
    );
    expect(
      imageUploadError(Exception('new row violates row-level security policy')),
      contains('سياسات Storage'),
    );
  });
}
