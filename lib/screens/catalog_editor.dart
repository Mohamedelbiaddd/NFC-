import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/i18n.dart';

import '../core/repository.dart';
import '../core/storage_service.dart';
import '../core/theme.dart';

/// Edits the catalog shown on a card's public page: products or services with
/// an optional photo, price and description.
class CatalogEditor extends StatefulWidget {
  const CatalogEditor({
    super.key,
    required this.repo,
    required this.tenant,
    required this.profileId,
    required this.title,
  });

  final Repository repo;
  final String tenant;
  final String profileId;
  final String title;

  @override
  State<CatalogEditor> createState() => _CatalogEditorState();
}

class _CatalogItem {
  _CatalogItem({String name = '', String price = '', String description = '', this.imageUrl})
    : name = TextEditingController(text: name),
      price = TextEditingController(text: price),
      description = TextEditingController(text: description);

  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController description;
  String? imageUrl;
  bool uploading = false;

  void dispose() {
    name.dispose();
    price.dispose();
    description.dispose();
  }

  Json? toJson() {
    final out = <String, dynamic>{};
    final n = name.text.trim(), p = price.text.trim(), d = description.text.trim();
    if (n.isNotEmpty) out['name'] = n;
    if (p.isNotEmpty) out['price'] = p;
    if (d.isNotEmpty) out['description'] = d;
    if (imageUrl != null && imageUrl!.isNotEmpty) out['image_url'] = imageUrl;
    if (!out.containsKey('name') && !out.containsKey('image_url')) return null;
    return out;
  }
}

class _CatalogEditorState extends State<CatalogEditor> {
  final picker = ImagePicker();
  late final ProfileImageStorage storage;
  final items = <_CatalogItem>[];
  bool loading = true, saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    storage = ProfileImageStorage(widget.repo.client);
    _load();
  }

  @override
  void dispose() {
    for (final item in items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final row = await widget.repo.profile(widget.profileId, widget.tenant);
      final raw = row['catalog'];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            items.add(
              _CatalogItem(
                name: '${e['name'] ?? ''}',
                price: '${e['price'] ?? ''}',
                description: '${e['description'] ?? ''}',
                imageUrl: e['image_url'] is String ? e['image_url'] as String : null,
              ),
            );
          }
        }
      }
    } catch (e) {
      error = userError(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickImage(_CatalogItem item) async {
    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final payload = decodeImagePayload(await file.readAsBytes());
      if (payload == null) {
        setState(() => error = tr('اختر صورة JPG أو PNG أو WebP أصغر من 5 ميجابايت.'));
        return;
      }
      setState(() {
        item.uploading = true;
        error = null;
      });
      final url = await storage.uploadImage(
        tenantId: widget.tenant,
        profileId: widget.profileId,
        payload: payload,
      );
      if (mounted) setState(() => item.imageUrl = url);
    } catch (e) {
      if (mounted) setState(() => error = imageUploadError(e));
    } finally {
      if (mounted) setState(() => item.uploading = false);
    }
  }

  Future<void> _save() async {
    if (items.any((i) => i.uploading)) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final catalog = items.map((i) => i.toJson()).whereType<Json>().toList();
      await widget.repo.save('nfc_profiles', {'catalog': catalog}, id: widget.profileId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = userError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _itemCard(int index, _CatalogItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: item.uploading ? null : () => _pickImage(item),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: item.uploading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : item.imageUrl != null
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image_outlined),
                          )
                        : const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.primarySoft,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: item.name,
                        maxLength: 120,
                        decoration: InputDecoration(
                          labelText: tr('الاسم'),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: item.price,
                        maxLength: 40,
                        decoration: InputDecoration(
                          labelText: tr('السعر (اختياري)'),
                          counterText: '',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr('حذف'),
                  onPressed: () => setState(() {
                    items.removeAt(index).dispose();
                  }),
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: item.description,
              maxLength: 1000,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: tr('الوصف (اختياري)'),
                counterText: '',
              ),
            ),
            if (item.imageUrl != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => setState(() => item.imageUrl = null),
                  child: Text(tr('إزالة الصورة')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('الكتالوج'), style: TextStyle(fontSize: 18)),
            Text(
              widget.title,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving || loading ? null : _save,
            child: Text(saving ? tr('جارٍ الحفظ…') : tr('حفظ')),
          ),
        ],
      ),
      floatingActionButton: loading
          ? null
          : FloatingActionButton.extended(
              onPressed: items.length >= 60
                  ? null
                  : () => setState(() => items.add(_CatalogItem())),
              icon: const Icon(Icons.add),
              label: Text(tr('إضافة عنصر')),
            ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(error!, style: const TextStyle(color: AppColors.danger)),
                  ),
                if (items.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Text(
                      tr('لا توجد عناصر بعد. أضف منتجات أو خدمات بصورها وأسعارها، وستظهر في صفحة البطاقة تحت عنوان «الكتالوج».'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.7),
                    ),
                  ),
                for (var i = 0; i < items.length; i++) _itemCard(i, items[i]),
              ],
            ),
    );
  }
}
