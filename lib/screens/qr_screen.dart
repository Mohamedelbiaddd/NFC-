import 'dart:ui' as ui;
import '../core/i18n.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Shows the public `/p/<slug>` link as a 58 mm thermal-label sized QR code and
/// saves the label as a PNG in the phone gallery for printing.
class QrScreen extends StatefulWidget {
  const QrScreen({
    super.key,
    required this.url,
    required this.title,
    required this.business,
    required this.slug,
    this.published = true,
    this.onSaved,
  });

  final String url;
  final String title;
  final String business;
  final String slug;
  final bool published;

  /// Called after the label lands in the phone gallery, so the dashboard can
  /// record a `qr_saved` event in the activity trail.
  final Future<void> Function()? onSaved;

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  final labelKey = GlobalKey();
  bool saving = false;
  String? message;

  Future<void> saveLabel() async {
    if (saving) return;
    setState(() {
      saving = true;
      message = null;
    });
    try {
      if (kIsWeb) {
        throw StateError(tr('حفظ الصورة في المعرض متاح على تطبيق الهاتف فقط.'));
      }
      final boundary = labelKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw StateError(tr('تعذّر تجهيز صورة الملصق، أعد المحاولة.'));
      }
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError(tr('تعذّر إنشاء صورة PNG للملصق.'));
        var granted = await Gal.hasAccess();
        if (!granted) granted = await Gal.requestAccess();
        if (!granted) {
          throw StateError(
            tr('لم يُسمح بالوصول إلى المعرض. فعّل صلاحية الصور من إعدادات التطبيق ثم أعد المحاولة.'),
          );
        }
        await Gal.putImageBytes(
          data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
          name: 'nfc-qr-${widget.slug}',
        );
      } finally {
        image.dispose();
      }
      if (!mounted) return;
      setState(
        () => message =
            tr('تم حفظ صورة الـ QR في معرض الهاتف. اطبعها كملصق حراري 58 مم والصقها على البطاقة.'),
      );
      await widget.onSaved?.call();
    } on GalException catch (e) {
      if (mounted) setState(() => message = galleryMessage(e.type));
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is StateError
              ? e.message
              : trf('تعذّر حفظ الصورة في المعرض: {0}', [e]),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String galleryMessage(GalExceptionType type) => switch (type) {
    GalExceptionType.accessDenied =>
      tr('لم يُسمح بالوصول إلى المعرض. فعّل صلاحية الصور من إعدادات التطبيق.'),
    GalExceptionType.notEnoughSpace =>
      tr('لا توجد مساحة كافية في الجهاز لحفظ الصورة.'),
    GalExceptionType.notSupportedFormat =>
      tr('صيغة الصورة غير مدعومة على هذا الجهاز.'),
    GalExceptionType.unexpected => tr('حدث خطأ غير متوقع أثناء حفظ الصورة.'),
  };

  Future<void> copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('تم نسخ الرابط'))));
  }

  /// The printable label. It is a fixed 384 logical pixels wide, which is the
  /// dot width of a 58 mm / 203 dpi thermal printer.
  Widget label() => Container(
    width: 384,
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.business.isNotEmpty)
          Text(
            widget.business,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
        if (widget.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black87, fontSize: 15),
            ),
          ),
        const SizedBox(height: 14),
        QrImageView(
          data: widget.url,
          version: QrVersions.auto,
          size: 300,
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Colors.black,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Colors.black,
          ),
          semanticsLabel: tr('رمز QR لرابط الملف'),
        ),
        const SizedBox(height: 12),
        Text(
          widget.slug,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('امسح الرمز لفتح الملف الرقمي'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('رمز QR للطباعة'))),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: RepaintBoundary(
              key: labelKey,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: label(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (!widget.published)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              tr('هذا الملف ما زال مسودة. لن يعمل الرابط حتى تنشره من شاشة التعديل.'),
              style: TextStyle(color: Color(0xFFFFB86B)),
            ),
          ),
        SelectableText(
          widget.url,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF6EE7D1)),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: saving ? null : saveLabel,
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          label: Text(saving ? tr('جارٍ الحفظ…') : tr('حفظ الصورة للطباعة')),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: saving ? null : copyLink,
          icon: const Icon(Icons.link),
          label: Text(tr('نسخ الرابط')),
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(message!),
          ),
        const SizedBox(height: 18),
        Text(
          tr('التلميح: احفظ الصورة ثم افتح تطبيق الطابعة الحرارية واختر الصورة من المعرض. الملصق بعرض 384 نقطة (58 مم) وأبيض وأسود ليبقى واضحاً عند الطباعة.'),
          style: TextStyle(color: Color(0xFFA7AEC6), fontSize: 13),
        ),
      ],
    ),
  );
}
