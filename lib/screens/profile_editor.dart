import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/repository.dart';
import '../core/app_config.dart';

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
  late TextEditingController title, slug, description;
  final inputs = <String, TextEditingController>{};
  late String kind;
  String? business;
  bool published = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final p = widget.profile;
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
      await widget.repo.save('nfc_profiles', {
        'tenant_id': widget.tenant,
        'business_id': business,
        'kind': kind,
        'title': title.text.trim(),
        'custom_slug': slug.text.trim(),
        'data': data,
        'published': published,
      }, id: widget.profile?['id']);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is PostgrestException && e.code == '23505'
              ? 'هذا الاسم مستخدم أو محجوز سابقاً. اختر اسماً آخر.'
              : userError(e),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.profile?['slug_locked'] == true;
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
                  readOnly: locked || busy,
                  textDirection: TextDirection.ltr,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'الاسم المخصص · custom_slug',
                    hintText: 'ahmad-electric',
                    helperText: locked
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
