import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/repository.dart';
import '../core/app_config.dart';
import '../core/storage_service.dart';

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({
    super.key,
    required this.repo,
    required this.tenant,
    required this.businesses,
    this.profile,
  });
  final Repository repo;
  final String tenant;
  final List<Json> businesses;
  final Json? profile;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final form = GlobalKey<FormState>();
  final picker = ImagePicker();
  late final ProfileImageStorage storage;
  late TextEditingController title, slug, description;
  final inputs = <String, TextEditingController>{};
  late String kind;
  String? business;
  bool published = false, busy = false;
  bool uploading = false;
  String? error;

  // Cover image state: `imageUrl` is what is stored in nfc_profiles.image_url,
  // `pending` holds a newly picked image for a profile that does not exist yet.
  String? imageUrl;
  String? originalImage;
  ImagePayload? pending;
  String? savedId;

  @override
  void initState() {
    super.initState();
    storage = ProfileImageStorage(widget.repo.client);
    final p = widget.profile;
    savedId = p?['id'] as String?;
    imageUrl = p?['image_url'] as String?;
    originalImage = imageUrl;
    title = TextEditingController(text: p?['title'] ?? '');
    slug = TextEditingController(text: p?['custom_slug'] ?? '');
    description = TextEditingController(text: p?['data']?['description'] ?? '');
    kind = p?['kind'] ?? 'vcard';
    business = p?['business_id'] ?? widget.businesses.firstOrNull?['id'];
    published = p?['published'] ?? false;
    for (final group in fieldsByKind.values) {
      for (final key in group.keys) {
        inputs.putIfAbsent(
          key,
          () => TextEditingController(text: p?['data']?[key] ?? ''),
        );
      }
    }
  }

  @override
  void dispose() {
    title.dispose();
    slug.dispose();
    description.dispose();
    for (final c in inputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get locked => busy || uploading;

  /// Picks an image from the gallery and uploads it immediately when the
  /// profile already exists. A new profile uploads right after it is created,
  /// because Storage paths and policies are scoped by profile id.
  Future<void> chooseImage() async {
    if (locked) return;
    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 88,
      );
      if (file == null) return;
      final payload = decodeImagePayload(await file.readAsBytes());
      if (payload == null) {
        if (mounted) {
          setState(
            () => error =
                'اختر صورة JPG أو PNG أو WebP صالحة أصغر من 5 ميجابايت.',
          );
        }
        return;
      }
      final id = savedId;
      if (id == null) {
        if (mounted) {
          setState(() {
            pending = payload;
            error = null;
          });
        }
        return;
      }
      await uploadNow(id, payload);
    } catch (e) {
      if (mounted) setState(() => error = imageUploadError(e));
    }
  }

  Future<void> uploadNow(String profileId, ImagePayload payload) async {
    setState(() {
      uploading = true;
      error = null;
    });
    try {
      final url = await storage.uploadImage(
        tenantId: widget.tenant,
        profileId: profileId,
        payload: payload,
      );
      await widget.repo.save('nfc_profiles', {'image_url': url}, id: profileId);
      final previous = imageUrl;
      if (!mounted) return;
      setState(() {
        imageUrl = url;
        pending = null;
      });
      if (previous != null && previous != url) {
        await storage.deleteImage(previous);
      }
    } catch (e) {
      if (mounted) setState(() => error = imageUploadError(e));
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  void removeImage() {
    if (locked) return;
    setState(() {
      pending = null;
      imageUrl = null;
      error = null;
    });
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || business == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = <String, dynamic>{
        'description': description.text.trim(),
        for (final k in fieldsByKind[kind]!.keys) k: inputs[k]!.text.trim(),
      };
      final payload = pending;
      final removed = imageUrl == null ? originalImage : null;
      var id = await widget.repo.save('nfc_profiles', {
        'tenant_id': widget.tenant,
        'business_id': business,
        'kind': kind,
        'title': title.text.trim(),
        'custom_slug': slug.text.trim(),
        'data': data,
        'published': published,
        'image_url': imageUrl,
      }, id: savedId);
      // Keep the created id so a retry after a failed upload updates the same
      // row instead of inserting a duplicate profile.
      if (id != null) savedId = id;
      if (payload != null && id != null) {
        final url = await storage.uploadImage(
          tenantId: widget.tenant,
          profileId: id,
          payload: payload,
        );
        await widget.repo.save('nfc_profiles', {'image_url': url}, id: id);
        imageUrl = url;
        originalImage = url;
        pending = null;
      }
      if (removed != null && removed != imageUrl) {
        await storage.deleteImage(removed);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = saveError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String saveError(Object e) {
    if (e is PostgrestException) {
      if (e.code == '23505') {
        return 'هذا الاسم مستخدم أو محجوز سابقاً. اختر اسماً آخر.';
      }
      return userError(e);
    }
    return imageUploadError(e);
  }

  Widget placeholder({bool loading = false}) => Container(
    color: const Color(0xFF232941),
    child: Icon(
      loading ? Icons.hourglass_empty : Icons.image_outlined,
      color: const Color(0xFF7C87A8),
    ),
  );

  Widget previewBox() {
    final bytes = pending;
    if (bytes != null) {
      return Image.memory(
        bytes.bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    final url = imageUrl;
    if (url != null && url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder(loading: true),
      );
    }
    return placeholder();
  }

  Widget imageBlock(BuildContext context) {
    final hasImage = pending != null || imageUrl != null;
    final hint = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: const Color(0xFFA7AEC6));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3150)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 96, height: 96, child: previewBox()),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'صورة الملف / الشعار',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تُرفع إلى Supabase Storage وتُحفظ في الحقل image_url، '
                      'ثم تظهر أعلى صفحة الويب العامة. JPG أو PNG أو WebP '
                      'حتى 5 ميجابايت.',
                      style: hint,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        OutlinedButton.icon(
                          onPressed: locked ? null : chooseImage,
                          icon: uploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.photo_library_outlined,
                                  size: 18,
                                ),
                          label: Text(
                            uploading
                                ? 'جارٍ الرفع…'
                                : hasImage
                                ? 'تغيير الصورة'
                                : 'اختيار صورة ورفعها',
                          ),
                        ),
                        if (hasImage && !uploading)
                          TextButton.icon(
                            onPressed: locked ? null : removeImage,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('إزالة'),
                          ),
                      ],
                    ),
                    if (pending != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'ستُرفع هذه الصورة عند حفظ الملف.',
                          style: hint,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slugLocked = widget.profile?['slug_locked'] == true;
    String preview = 'https://yourdomain.com/p/${slug.text}';
    if (AppConfig.profileBase.isNotEmpty && AppConfig.validSlug(slug.text)) {
      try {
        preview = AppConfig.profileUrl(
          AppConfig.profileBase,
          slug.text,
        ).toString();
      } catch (_) {}
    }
    return AlertDialog(
      title: Text(widget.profile == null ? 'إنشاء ملف NFC' : 'تعديل ملف NFC'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: business,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'النشاط التجاري',
                  ),
                  items: widget.businesses
                      .map(
                        (b) => DropdownMenuItem<String>(
                          value: b['id'],
                          child: Text(b['name']),
                        ),
                      )
                      .toList(),
                  onChanged: busy ? null : (v) => setState(() => business = v),
                  validator: (v) => v == null ? 'اختر النشاط' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: title,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'عنوان الملف'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: slug,
                  readOnly: slugLocked || busy,
                  textDirection: TextDirection.ltr,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'الاسم المخصص · custom_slug',
                    hintText: 'ahmad-electric',
                    helperText: slugLocked
                        ? 'الاسم ثابت منذ أول نشر لحماية البطاقات'
                        : '3–63: أحرف إنجليزية صغيرة، أرقام، شرطات مفردة',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => AppConfig.validSlug(v?.trim() ?? '')
                      ? null
                      : 'اسم غير صالح أو محجوز',
                ),
                const SizedBox(height: 8),
                SelectableText(
                  preview,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: Color(0xFF6EE7D1)),
                ),
                const SizedBox(height: 14),
                imageBlock(context),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'نوع القالب'),
                  items: kindNames.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: busy ? null : (v) => setState(() => kind = v!),
                ),
                const SizedBox(height: 14),
                for (final e in fieldsByKind[kind]!.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextFormField(
                      controller: inputs[e.key],
                      maxLength: 2000,
                      decoration: InputDecoration(labelText: e.value),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (e.value.endsWith('*') && text.isEmpty) {
                          return 'مطلوب';
                        }
                        if (text.isNotEmpty &&
                            (e.key.endsWith('_url') || e.key == 'website') &&
                            !validHttps(text)) {
                          return 'أدخل رابط HTTPS صالحاً';
                        }
                        return null;
                      },
                    ),
                  ),
                TextFormField(
                  controller: description,
                  maxLength: 2000,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'الوصف العام'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: published,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => published = v!),
                  title: const Text('نشر الملف للعامة'),
                  subtitle: const Text(
                    'كل بيانات هذا الملف تصبح عامة عبر الرابط. الاسم يثبت نهائياً عند أول نشر. لا تدخل بيانات حساسة.',
                  ),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'جارٍ الحفظ…' : 'حفظ الملف'),
        ),
      ],
    );
  }
}
