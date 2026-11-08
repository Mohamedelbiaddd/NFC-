import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../core/people.dart';
import '../core/repository.dart';
import '../core/storage_service.dart';
import '../core/theme.dart';

/// One clear form for adding or editing a person (vCard) or another card kind.
/// Image picking/uploads, slug suggestion and publishing live here so the
/// dashboard only has to refresh its list afterwards.
class PersonForm extends StatefulWidget {
  const PersonForm({
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
  State<PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends State<PersonForm> {
  final form = GlobalKey<FormState>();
  final picker = ImagePicker();
  late final ProfileImageStorage storage;

  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final website = TextEditingController();
  final description = TextEditingController();
  final slug = TextEditingController();
  final extra = <String, TextEditingController>{};

  late String kind;
  String? business;
  bool published = true;
  bool busy = false;
  bool uploading = false;
  String? error;

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
    kind = '${p?['kind'] ?? 'vcard'}';
    business = p?['business_id'] as String? ??
        widget.businesses.firstOrNull?['id'] as String?;
    published = p == null ? true : personPublished(p);

    if (p != null) {
      final full = profileField(p, 'full_name');
      name.text = full.isNotEmpty ? full : '${p['title'] ?? ''}';
      phone.text = profileField(p, 'phone');
      email.text = profileField(p, 'email');
      website.text = profileField(p, 'website');
      description.text = profileField(p, 'description');
      slug.text = personSlug(p);
      for (final key in (fieldsByKind[kind] ?? const <String, String>{}).keys) {
        extra[key] = TextEditingController(text: profileField(p, key));
      }
    } else {
      slug.text = _suggestSlug();
    }
  }

  // Longer random slugs make public links hard to guess or enumerate.
  static String _suggestSlug() {
    final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final random = Random.secure();
    const alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
    final salt = List.generate(
      4,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return 'card-$stamp$salt';
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    website.dispose();
    description.dispose();
    slug.dispose();
    for (final controller in extra.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get locked => busy || uploading;

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
        setState(
          () => error = 'اختر صورة JPG أو PNG أو WebP أصغر من 5 ميجابايت.',
        );
        return;
      }
      if (savedId == null) {
        setState(() {
          pending = payload;
          error = null;
        });
        return;
      }
      await _uploadNow(savedId!, payload);
    } catch (e) {
      if (mounted) setState(() => error = imageUploadError(e));
    }
  }

  Future<void> _uploadNow(String profileId, ImagePayload payload) async {
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

  String _errorFor(Object e) {
    if (e is PostgrestException) {
      if (e.code == '23505') {
        return 'هذا الرابط المختصر مستخدم. اختر رابطاً آخر.';
      }
      return userError(e);
    }
    return imageUploadError(e);
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (business == null) {
      setState(() => error = 'أضف نشاطاً تجارياً أولاً.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final payload = pending;
      final removed = imageUrl == null ? originalImage : null;
      final data = <String, dynamic>{
        'description': description.text.trim(),
      };
      if (kind == 'vcard') {
        data['full_name'] = name.text.trim();
        data['phone'] = phone.text.trim();
        data['email'] = email.text.trim();
        data['website'] = website.text.trim();
      } else {
        for (final key in (fieldsByKind[kind] ?? const <String, String>{}).keys) {
          data[key] = extra[key]?.text.trim() ?? '';
        }
      }

      var id = await widget.repo.save('nfc_profiles', {
        'tenant_id': widget.tenant,
        'business_id': business,
        'kind': kind,
        'title': name.text.trim(),
        'custom_slug': slug.text.trim(),
        'data': data,
        'published': published,
        'image_url': imageUrl,
      }, id: savedId);
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
      if (mounted) setState(() => error = _errorFor(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _imagePicker() {
    final hasImage = pending != null || imageUrl != null;
    Widget inner;
    if (pending != null) {
      inner = Image.memory(
        pending!.bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } else if (imageUrl != null) {
      inner = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image_outlined,
          color: AppColors.muted,
        ),
      );
    } else {
      inner = const Icon(
        Icons.add_a_photo_outlined,
        color: AppColors.primarySoft,
        size: 26,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: locked ? null : chooseImage,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: uploading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : inner,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hasImage ? 'تغيير' : 'صورة',
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        if (hasImage && !uploading)
          TextButton(
            onPressed: locked
                ? null
                : () => setState(() {
                    pending = null;
                    imageUrl = null;
                  }),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 24),
            ),
            child: const Text('إزالة', style: TextStyle(fontSize: 11)),
          ),
      ],
    );
  }

  Widget _kindField(String key, String label) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: TextFormField(
      controller: extra.putIfAbsent(key, TextEditingController.new),
      maxLength: 2000,
      textDirection: key.endsWith('_url') ? TextDirection.ltr : null,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (label.endsWith('*') && text.isEmpty) return 'مطلوب';
        if (text.isNotEmpty &&
            (key.endsWith('_url') || key == 'website') &&
            !validHttps(text)) {
          return 'أدخل رابط HTTPS صالحاً';
        }
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isVcard = kind == 'vcard';
    var preview = '/p/${slug.text}';
    if (AppConfig.profileBase.isNotEmpty && AppConfig.validSlug(slug.text)) {
      try {
        preview = AppConfig.profileUrl(
          AppConfig.profileBase,
          slug.text,
        ).toString();
      } catch (_) {}
    }
    return AlertDialog(
      title: Text(widget.profile == null ? 'إضافة شخص' : 'تعديل البطاقة'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _imagePicker(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: name,
                        maxLength: 120,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: isVcard ? 'اسم الشخص' : 'عنوان البطاقة',
                          counterText: '',
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? 'الاسم مطلوب' : null,
                      ),
                    ),
                  ],
                ),
                if (isVcard) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return null;
                      return RegExp(r'^[+0-9 ()-]{3,40}$').hasMatch(text)
                          ? null
                          : 'رقم غير صالح';
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return null;
                      return text.contains('@') && !text.contains(' ')
                          ? null
                          : 'بريد غير صالح';
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: website,
                    keyboardType: TextInputType.url,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'الموقع (HTTPS) — اختياري',
                      prefixIcon: Icon(Icons.language),
                    ),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return null;
                      return validHttps(text) ? null : 'أدخل رابط HTTPS صالحاً';
                    },
                  ),
                ] else
                  ...(fieldsByKind[kind] ?? const <String, String>{})
                      .entries
                      .map((entry) => _kindField(entry.key, entry.value)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: description,
                  maxLength: 2000,
                  maxLines: 2,
                  minLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'وصف قصير — اختياري',
                    counterText: '',
                  ),
                ),
                if (widget.businesses.length > 1) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: business,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'النشاط التجاري',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    items: widget.businesses
                        .map(
                          (b) => DropdownMenuItem<String>(
                            value: b['id'] as String?,
                            child: Text('${b['name']}'),
                          ),
                        )
                        .toList(),
                    onChanged: locked
                        ? null
                        : (v) => setState(() => business = v),
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: published,
                  onChanged: locked
                      ? null
                      : (v) => setState(() => published = v),
                  title: const Text('نشر البطاقة للعامة'),
                  subtitle: const Text(
                    'يظهر الرابط ورمز QR للزبائن مباشرة بعد الحفظ.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 4),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: const Text(
                    'خيارات متقدمة',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: kind,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'نوع البطاقة',
                      ),
                      items: kindNames.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: locked
                          ? null
                          : (v) => setState(() => kind = v!),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: slug,
                      textDirection: TextDirection.ltr,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'الرابط المختصر · custom_slug',
                        prefixIcon: const Icon(Icons.link),
                        helperText: 'يُثبَّت بعد أول نشر لحماية البطاقة',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => AppConfig.validSlug(v?.trim() ?? '')
                          ? null
                          : '3–63 حرفاً لاتينياً صغيراً وأرقاماً وشرطات',
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SelectableText(
                        preview,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: busy ? null : save,
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 20),
          label: Text(busy ? 'جارٍ الحفظ…' : 'حفظ'),
        ),
      ],
    );
  }
}
