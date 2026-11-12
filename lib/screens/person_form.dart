import 'dart:math';
import '../core/i18n.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../core/network_service.dart';
import '../core/shops_service.dart';
import '../core/people.dart';
import '../core/repository.dart';
import '../core/storage_service.dart';
import '../core/theme.dart';
import 'catalog_editor.dart';
import 'shops_tab.dart' show ShopForm, showShopAccess;
import 'writer_screen.dart';

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

/// Colour themes of the business card page (same keys as web_profiles/vcard.mjs):
/// name, card colour, accent.
const cardThemes = <String, (String, Color, Color)>{
  'violet': ('بنفسجي', Color(0xFF120A24), Color(0xFF8B5CF6)),
  'navy': ('كحلي وذهبي', Color(0xFF0B1A36), Color(0xFFF6C232)),
  'black': ('أسود فاخر', Color(0xFF121212), Color(0xFFD4AF37)),
  'emerald': ('زمردي', Color(0xFF082319), Color(0xFF34D399)),
  'ocean': ('أزرق المحيط', Color(0xFF072235), Color(0xFF38BDF8)),
  'rose': ('وردي', Color(0xFF2A0C1B), Color(0xFFF472B6)),
  'sunset': ('برتقالي', Color(0xFF271205), Color(0xFFFB923C)),
  'crimson': ('أحمر', Color(0xFF22070F), Color(0xFFF43F5E)),
  'neon': ('أسود ونيون', Color(0xFF111411), Color(0xFFA3E635)),
  'coffee': ('بني', Color(0xFF21140C), Color(0xFFD6A15A)),
  'ivory': ('عاجي فاتح', Color(0xFFFFFFFF), Color(0xFFB8860B)),
  'sky': ('أبيض وأزرق', Color(0xFFFFFFFF), Color(0xFF2563EB)),
};
/// Ready-made designs (same ids as web_profiles/card-themes.json): id, name,
/// group (craft / executive), card colour, accent, layout, has a cover picture.
/// To add a design: add it to card-themes.json (+ its pictures in
/// web_profiles/themes/) and one line here.
const cardDesigns = <(String, String, String, Color, Color, String, bool)>[
  ('electrician', 'كهربائي', 'craft', Color(0xFF101E30), Color(0xFFF5BD5D), 'classic', true),
  ('plumber', 'سباك', 'craft', Color(0xFF103B3D), Color(0xFFF0AD79), 'classic', true),
  ('builder', 'البناء والترميم', 'craft', Color(0xFFF2E4CE), Color(0xFF923B26), 'classic', true),
  ('carpenter', 'نجار', 'craft', Color(0xFFF1E2C7), Color(0xFF4B5328), 'classic', true),
  ('metalworker', 'حداد', 'craft', Color(0xFF252322), Color(0xFFEDAB73), 'classic', true),
  ('decorator', 'صباغ وديكور', 'craft', Color(0xFFEEE6D7), Color(0xFF205445), 'classic', true),
  ('barber', 'حلاق', 'craft', Color(0xFF3E1720), Color(0xFFF5CE87), 'classic', true),
  ('carwash', 'غسل السيارات', 'craft', Color(0xFF0C2946), Color(0xFF7DE3FF), 'classic', true),
  ('bookshop', 'مكتبة', 'craft', Color(0xFFF1F7FA), Color(0xFF145D89), 'classic', true),
  ('tailor', 'خياطة وأثواب', 'craft', Color(0xFF101E36), Color(0xFFF2CC82), 'classic', true),
  ('pastries', 'حلويات مغربية', 'craft', Color(0xFFFFF1D9), Color(0xFF255537), 'classic', true),
  ('zellige', 'صناعة الزليج', 'craft', Color(0xFFF3EAD9), Color(0xFF235B48), 'classic', true),
  ('ivory-director', 'عاجي هادئ', 'executive', Color(0xFFF7F4EB), Color(0xFF526750), 'minimal', false),
  ('navy-boardroom', 'كحلي رسمي', 'executive', Color(0xFF142136), Color(0xFF8EB8D5), 'center', false),
  ('white-consulting', 'أبيض للاستشارات', 'executive', Color(0xFFFFFFFF), Color(0xFF254A62), 'minimal', false),
  ('slate-signature', 'توقيع فحمي', 'executive', Color(0xFF222629), Color(0xFFE5C996), 'center', false),
  ('sage-office', 'أخضر مكتبي', 'executive', Color(0xFFEBF1E9), Color(0xFF365D4E), 'minimal', false),
  ('sand-studio', 'رملي معماري', 'executive', Color(0xFFF6EEE4), Color(0xFF764634), 'center', false),
];
const cardColors = ['#8B5CF6', '#2563EB', '#0EA5E9', '#10B981', '#84CC16', '#F59E0B', '#F97316', '#EF4444', '#EC4899', '#D4AF37'];
const cardLayouts = <String, (String, IconData)>{
  'classic': ('كلاسيكي', Icons.view_agenda_rounded),
  'center': ('في الوسط', Icons.account_circle_rounded),
  'minimal': ('بسيط', Icons.crop_square_rounded),
};
const socialFields = <String, String>{
  'instagram': 'Instagram',
  'tiktok': 'TikTok',
  'facebook': 'Facebook',
  'linkedin': 'LinkedIn',
  'x': 'X / Twitter',
  'youtube': 'YouTube',
  'snapchat': 'Snapchat',
  'telegram': 'Telegram',
};
Color _hex(String h) => Color(int.parse('FF${h.substring(1)}', radix: 16));

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
  final pin = TextEditingController();
  bool hasPin = false;
  final extra = <String, TextEditingController>{};
  // Business card extras.
  final jobTitle = TextEditingController();
  final company = TextEditingController();
  final whatsapp = TextEditingController();
  final address = TextEditingController();
  final quote = TextEditingController();
  final social = {for (final k in socialFields.keys) k: TextEditingController()};
  String cardTheme = 'violet';
  String cardLayout = 'classic';
  String? cardColor;
  String? coverUrl;
  String? originalCover;
  ImagePayload? pendingCover;
  Map<String, dynamic> originalData = {};

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
      jobTitle.text = profileField(p, 'job_title');
      company.text = profileField(p, 'company');
      whatsapp.text = profileField(p, 'whatsapp');
      address.text = profileField(p, 'address');
      quote.text = profileField(p, 'quote');
      for (final e in social.entries) {
        e.value.text = profileField(p, e.key);
      }
      final th = profileField(p, 'theme');
      if (cardThemes.containsKey(th) || cardDesigns.any((d) => d.$1 == th)) cardTheme = th;
      final lay = profileField(p, 'layout');
      if (cardLayouts.containsKey(lay)) cardLayout = lay;
      final col = profileField(p, 'color');
      if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(col)) cardColor = col.toUpperCase();
      final cov = profileField(p, 'cover_url');
      if (cov.isNotEmpty) coverUrl = originalCover = cov;
      final raw = p['data'];
      if (raw is Map) originalData = Map<String, dynamic>.from(raw);
      slug.text = personSlug(p);
      widget.repo.profileHasPin('${p['id']}').then((value) {
        if (mounted) setState(() => hasPin = value);
      });
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
    pin.dispose();
    for (final c in [jobTitle, company, whatsapp, address, quote, ...social.values]) {
      c.dispose();
    }
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
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (file == null) return;
      final payload = decodeImagePayload(await file.readAsBytes());
      if (payload == null) {
        setState(
          () => error = tr('اختر صورة JPG أو PNG أو WebP أصغر من 5 ميجابايت.'),
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
        return tr('هذا الرابط المختصر مستخدم. اختر رابطاً آخر.');
      }
      return userError(e);
    }
    return imageUploadError(e);
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (business == null) {
      setState(() => error = tr('أضف نشاطاً تجارياً أولاً.'));
      return;
    }
    // A loyalty card always opens a shop page (/c/…): without one, create the
    // shop now (name prefilled) instead of saving a card that leads nowhere.
    if (kind == 'loyalty' && _shopSlug == null) {
      await _createShop();
      if (!mounted) return;
      if (_shopSlug == null) {
        setState(() => error = tr('أنشئ برنامج الولاء (المحل) أولاً ليعمل الرابط.'));
        return;
      }
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
        // Keep keys set elsewhere (the web editor), then this form's fields.
        for (final e in originalData.entries) {
          if (e.value is String && '${e.value}'.isNotEmpty) data[e.key] = e.value;
        }
        data['full_name'] = name.text.trim();
        data['phone'] = phone.text.trim();
        data['email'] = email.text.trim();
        data['website'] = website.text.trim();
        data['job_title'] = jobTitle.text.trim();
        data['company'] = company.text.trim();
        data['whatsapp'] = whatsapp.text.trim();
        data['address'] = address.text.trim();
        data['quote'] = quote.text.trim();
        for (final e in social.entries) {
          data[e.key] = e.value.text.trim();
        }
        data['theme'] = cardTheme;
        data['layout'] = cardLayout;
        data['color'] = cardColor ?? '';
        data['cover_url'] = coverUrl ?? '';
        data.removeWhere((k, v) => k != 'full_name' && k != 'description' && v is String && v.isEmpty);
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
      // The business card cover picture.
      if (kind == 'vcard' && id != null) {
        final cover = pendingCover;
        if (cover != null) {
          final url = await storage.uploadImage(tenantId: widget.tenant, profileId: id, payload: cover);
          data['cover_url'] = url;
          await widget.repo.save('nfc_profiles', {'data': data}, id: id);
          pendingCover = null;
          coverUrl = url;
        }
        if (originalCover != null && originalCover != coverUrl) {
          await storage.deleteImage(originalCover!);
        }
        originalCover = coverUrl;
      }
      final code = pin.text.trim();
      final shopSlug = _shopSlug;
      if (code.isNotEmpty && shopSlug != null) {
        await _setShopPassword(shopSlug, code);
      } else if (code.isNotEmpty && id != null) {
        await widget.repo.setProfilePin(id, code);
      }
      if (mounted) Navigator.pop(context, id ?? savedId ?? '');
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
          hasImage ? tr('تغيير') : tr('صورة'),
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
            child: Text(tr('إزالة'), style: TextStyle(fontSize: 11)),
          ),
      ],
    );
  }

  static String _randomPin() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  Future<void> _removePin() async {
    final id = savedId;
    if (id == null) return;
    try {
      await widget.repo.setProfilePin(id, '');
      if (mounted) {
        setState(() {
          hasPin = false;
          pin.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = userError(e));
    }
  }

  Future<void> _openCatalog() async {
    final id = savedId;
    if (id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CatalogEditor(
          repo: widget.repo,
          tenant: widget.tenant,
          profileId: id,
          title: name.text.trim(),
        ),
      ),
    );
  }

  /// Slug of the shop this loyalty card points to (…/c/<slug>), if any.
  String? get _shopSlug {
    if (kind != 'loyalty') return null;
    final url = extra['loyalty_url']?.text.trim() ?? '';
    return RegExp(r'/c/([a-z0-9]+(?:-[a-z0-9]+)*)/?$').firstMatch(url)?.group(1);
  }

  /// For a loyalty card linked to a shop, the "code" is the shop owner's
  /// password used on the shop page (4 taps on the photo), not a card PIN.
  Widget _shopOwnerSection() => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.key_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr('كلمة مرور صاحب المحل'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tr('يفتح صاحب المحل صفحته، ويضغط 4 مرات على صورته، ثم يكتب كلمة المرور هذه. تغييرها يلغي القفل بعد 3 محاولات خاطئة.'),
          style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: pin,
          textDirection: TextDirection.ltr,
          maxLength: 72,
          decoration: InputDecoration(
            labelText: tr('كلمة مرور جديدة (اتركها فارغة للإبقاء على الحالية)'),
            counterText: '',
            suffixIcon: IconButton(
              tooltip: tr('توليد'),
              onPressed: locked ? null : () => setState(() => pin.text = ShopsService.randomPassword()),
              icon: const Icon(Icons.casino_outlined),
            ),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty || text.length >= 6) return null;
            return tr('6 أحرف على الأقل');
          },
        ),
      ],
    ),
  );

  /// Sets the shop owner's password and shows it with the WhatsApp message.
  Future<void> _setShopPassword(String slug, String password) async {
    final shops = await NetworkService(widget.repo.client).shops();
    final shop = shops.where((s) => '${s['shop_slug']}' == slug).firstOrNull;
    if (shop == null) throw Exception(tr('لم أجد هذا المحل في شبكتك.'));
    await ShopsService(widget.repo.client).setup(
      businessId: '${shop['id']}',
      slug: slug,
      goal: (shop['goal'] as num?)?.toInt() ?? 5,
      reward: '${shop['reward'] ?? ''}',
      password: password,
    );
    if (mounted) await showShopAccess(context, shop, password);
  }

  Widget _ownerSection() => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.key_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr('رمز التعديل لصاحب البطاقة'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            if (hasPin)
              Pill(tr('مفعّل'), color: AppColors.success, icon: Icons.check_rounded),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tr('يضغط صاحب البطاقة 3 مرات على صورته في صفحته، ويكتب هذا الرمز ليعدّل بياناته وصوره والكتالوج بنفسه.'),
          style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: pin,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          maxLength: 12,
          decoration: InputDecoration(
            labelText: hasPin ? tr('رمز جديد (اتركه فارغاً للإبقاء على الحالي)') : tr('الرمز (6 أرقام أو أكثر) — اختياري'),
            counterText: '',
            suffixIcon: IconButton(
              tooltip: tr('توليد رمز'),
              onPressed: locked ? null : () => setState(() => pin.text = _randomPin()),
              icon: const Icon(Icons.casino_outlined),
            ),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return null;
            return RegExp(r'^[0-9]{6,12}$').hasMatch(text)
                ? null
                : tr('من 6 إلى 12 رقماً');
          },
        ),
        if (hasPin)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: locked ? null : _removePin,
              icon: const Icon(Icons.key_off_rounded, size: 16),
              label: Text(tr('إلغاء الرمز')),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            ),
          ),
        const Divider(height: 20),
        OutlinedButton.icon(
          onPressed: savedId == null || locked ? null : _openCatalog,
          icon: const Icon(Icons.grid_view_rounded, size: 18),
          label: Text(
            savedId == null
                ? tr('الكتالوج (احفظ البطاقة أولاً)')
                : tr('تعديل الكتالوج: منتجات وصور وأسعار'),
          ),
        ),
      ],
    ),
  );

  void _useShop(String slug) => setState(() {
    extra.putIfAbsent('loyalty_url', TextEditingController.new).text =
        ShopsService.customerLink(slug);
  });

  /// Creates a new loyalty programme (a shop) right here; its link fills the
  /// field and the owner password is shown to send on WhatsApp.
  Future<void> _createShop() async {
    final slug = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ShopForm(
          service: ShopsService(widget.repo.client),
          tenant: widget.tenant,
          initialName: name.text.trim().isEmpty ? null : name.text.trim(),
        ),
      ),
    );
    if (slug != null && mounted) _useShop(slug);
  }

  /// Fills the loyalty link from an existing shop, or creates a new one.
  Future<void> _pickShop() async {
    List<Json> shops;
    try {
      shops = (await NetworkService(widget.repo.client).shops())
          .where((s) => '${s['shop_slug'] ?? ''}'.isNotEmpty && s['suspended'] != true)
          .toList();
    } catch (e) {
      if (mounted) setState(() => error = userError(e));
      return;
    }
    if (!mounted) return;
    if (shops.isEmpty) return _createShop();
    final slug = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.add_business_rounded, color: AppColors.success),
              title: Text(tr('➕ إنشاء برنامج ولاء جديد'), style: const TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(context, ''),
            ),
            const Divider(),
            for (final shop in shops)
              ListTile(
                leading: const Icon(Icons.storefront_rounded),
                title: Text('${shop['name']}'),
                subtitle: Text(
                  ShopsService.customerLink('${shop['shop_slug']}'),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => Navigator.pop(context, '${shop['shop_slug']}'),
              ),
          ],
        ),
      ),
    );
    if (slug == null || !mounted) return;
    if (slug.isEmpty) return _createShop();
    _useShop(slug);
  }

  Widget _kindField(String key, String label) => key == 'loyalty_url'
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _plainKindField(key, label),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: busy ? null : _createShop,
              icon: const Icon(Icons.add_business_rounded, size: 18),
              label: Text(tr('➕ إنشاء برنامج ولاء جديد (الرابط يُنشأ تلقائياً)')),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: busy ? null : _pickShop,
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: Text(tr('أو اختر محلاً موجوداً')),
            ),
          ],
        )
      : _plainKindField(key, label);

  Widget _plainKindField(String key, String label) => Padding(
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
        if (label.endsWith('*') && text.isEmpty) return tr('مطلوب');
        if (text.isNotEmpty &&
            (key.endsWith('_url') || key == 'website') &&
            !validHttps(text)) {
          return tr('أدخل رابط HTTPS صالحاً');
        }
        return null;
      },
    ),
  );

  Future<void> chooseCover() async {
    if (locked) return;
    try {
      final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
      if (file == null) return;
      final payload = decodeImagePayload(await file.readAsBytes());
      if (payload == null) {
        setState(() => error = tr('اختر صورة JPG أو PNG أو WebP أصغر من 5 ميجابايت.'));
        return;
      }
      setState(() {
        pendingCover = payload;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = imageUploadError(e));
    }
  }

  String? _socialCheck(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    return RegExp(r'^(https://\S{3,250}|@?[A-Za-z0-9_.-]{1,80})$').hasMatch(t)
        ? null
        : tr('اكتب اسم الحساب (@name) أو رابطاً يبدأ بـ https://');
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      );

  /// Colour theme, own colour, shape and cover of the business card page.
  Widget _designSection() {
    final cover = pendingCover != null
        ? Image.memory(pendingCover!.bytes, fit: BoxFit.cover)
        : coverUrl != null
            ? Image.network(coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())
            : null;
    final design = cardDesigns.where((d) => d.$1 == cardTheme).firstOrNull;
    Widget designTile((String, String, String, Color, Color, String, bool) d) {
      final selected = cardTheme == d.$1;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: locked
              ? null
              : () => setState(() {
                    cardTheme = d.$1;
                    cardLayout = d.$6;
                    cardColor = null;
                  }),
          child: Container(
            width: 112,
            decoration: BoxDecoration(
              color: d.$4,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppColors.text : AppColors.border, width: selected ? 3 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 62,
                  child: d.$7 && AppConfig.profileBase.isNotEmpty
                      ? Image.network('${AppConfig.profileBase}/themes/${d.$1}-cover.webp', fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox())
                      : Center(
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: d.$5)),
                            child: Text('TM', style: TextStyle(color: d.$5, fontWeight: FontWeight.w800, fontSize: 11)),
                          ),
                        ),
                ),
                Container(height: 3, color: d.$5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Row(
                    children: [
                      if (selected) Icon(Icons.check_circle_rounded, size: 14, color: d.$5),
                      if (selected) const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          tr(d.$2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: d.$5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget designRow(String group) => SizedBox(
          height: 98,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [for (final d in cardDesigns.where((d) => d.$3 == group)) designTile(d)],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(tr('🎨 تصميم جاهز: الحرف والمهن')),
        designRow('craft'),
        _sectionTitle(tr('💼 تصميم جاهز: مدراء الأعمال')),
        designRow('executive'),
        if (design != null) ...[
          const SizedBox(height: 6),
          Text(trf('التصميم المختار: {0}', [tr(design.$2)]), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
        _sectionTitle(tr('🎨 أو لون بسيط')),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final e in cardThemes.entries)
              Tooltip(
                message: tr(e.value.$1),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: locked ? null : () => setState(() => cardTheme = e.key),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [e.value.$2, e.value.$3],
                      ),
                      border: Border.all(
                        color: cardTheme == e.key ? AppColors.text : AppColors.border,
                        width: cardTheme == e.key ? 3 : 1,
                      ),
                    ),
                    child: cardTheme == e.key
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (cardThemes[cardTheme] != null)
          Text(tr(cardThemes[cardTheme]!.$1), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        _sectionTitle(tr('لون خاص للأزرار (اختياري)')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(tr('حسب اللون')),
              selected: cardColor == null,
              onSelected: locked ? null : (_) => setState(() => cardColor = null),
            ),
            for (final c in cardColors)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: locked ? null : () => setState(() => cardColor = c),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _hex(c),
                    shape: BoxShape.circle,
                    border: Border.all(color: cardColor == c ? AppColors.text : Colors.transparent, width: 3),
                  ),
                ),
              ),
          ],
        ),
        _sectionTitle(tr('شكل البطاقة')),
        SegmentedButton<String>(
          segments: [
            for (final e in cardLayouts.entries)
              ButtonSegment(value: e.key, label: Text(tr(e.value.$1)), icon: Icon(e.value.$2, size: 18)),
          ],
          selected: {cardLayout},
          showSelectedIcon: false,
          onSelectionChanged: locked ? null : (v) => setState(() => cardLayout = v.first),
        ),
        if (cardLayout != 'minimal') ...[
          _sectionTitle(tr('صورة الغلاف (اختياري)')),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: locked ? null : chooseCover,
            child: Container(
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: cover ??
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primarySoft),
                        const SizedBox(width: 8),
                        Text(tr('اختر صورة للغلاف'), style: const TextStyle(color: AppColors.muted)),
                      ],
                    ),
                  ),
            ),
          ),
          if (cover != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: locked ? null : () => setState(() {
                  pendingCover = null;
                  coverUrl = null;
                }),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(tr('إزالة الغلاف')),
              ),
            ),
        ],
      ],
    );
  }

  /// Editing a saved card: its link with copy and "write to NFC" on top.
  Widget _linkBar(String link) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.link_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                link,
                textDirection: TextDirection.ltr,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.accent),
              ),
            ),
            IconButton(
              tooltip: tr('نسخ الرابط'),
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: link));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تم نسخ الرابط'))));
              },
            ),
            IconButton(
              tooltip: tr('اكتب الرابط على بطاقة NFC'),
              icon: const Icon(Icons.nfc_rounded, size: 20, color: AppColors.success),
              onPressed: locked || savedId == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => WriterScreen(
                            repo: widget.repo,
                            tenant: widget.tenant,
                            profileId: savedId!,
                            profileName: name.text.trim(),
                          ),
                        ),
                      ),
            ),
          ],
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
      title: Text(widget.profile == null ? tr('إضافة شخص') : tr('تعديل البطاقة')),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.profile != null && published && AppConfig.profileBase.isNotEmpty && AppConfig.validSlug(slug.text))
                  _linkBar(preview),
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
                          labelText: isVcard ? tr('اسم الشخص') : tr('عنوان البطاقة'),
                          counterText: '',
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? tr('الاسم مطلوب') : null,
                      ),
                    ),
                  ],
                ),
                if (isVcard) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: jobTitle,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: tr('المنصب / المهنة — اختياري'),
                      counterText: '',
                      prefixIcon: const Icon(Icons.work_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: company,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: tr('الشركة — اختياري'),
                      counterText: '',
                      prefixIcon: const Icon(Icons.apartment_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: tr('رقم الهاتف'),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return null;
                      return RegExp(r'^[+0-9 ()-]{3,40}$').hasMatch(text)
                          ? null
                          : tr('رقم غير صالح');
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: whatsapp,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: tr('واتساب — اختياري'),
                      prefixIcon: const Icon(Icons.chat_rounded),
                    ),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return null;
                      return RegExp(r'^[+0-9 ()-]{6,30}$').hasMatch(text) ? null : tr('رقم غير صالح');
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: tr('البريد الإلكتروني'),
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return null;
                      return text.contains('@') && !text.contains(' ')
                          ? null
                          : tr('بريد غير صالح');
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: website,
                    keyboardType: TextInputType.url,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: tr('الموقع (HTTPS) — اختياري'),
                      prefixIcon: Icon(Icons.language),
                    ),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return null;
                      return validHttps(text) ? null : tr('أدخل رابط HTTPS صالحاً');
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: address,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: tr('العنوان — اختياري'),
                      counterText: '',
                      prefixIcon: const Icon(Icons.place_outlined),
                    ),
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    leading: const Icon(Icons.share_rounded, color: AppColors.primarySoft),
                    title: Text(tr('روابط التواصل الاجتماعي')),
                    subtitle: Text(
                      tr('اكتب اسم الحساب (@name) أو الرابط'),
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    children: [
                      for (final e in socialFields.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextFormField(
                            controller: social[e.key],
                            textDirection: TextDirection.ltr,
                            autocorrect: false,
                            decoration: InputDecoration(labelText: e.value, hintText: '@name'),
                            validator: _socialCheck,
                          ),
                        ),
                    ],
                  ),
                  TextFormField(
                    controller: quote,
                    maxLength: 300,
                    maxLines: 2,
                    minLines: 1,
                    decoration: InputDecoration(
                      labelText: tr('عبارة مميزة تظهر في البطاقة — اختياري'),
                      counterText: '',
                      prefixIcon: const Icon(Icons.format_quote_rounded),
                    ),
                  ),
                  _designSection(),
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
                  decoration: InputDecoration(
                    labelText: tr('وصف قصير — اختياري'),
                    counterText: '',
                  ),
                ),
                if (widget.businesses.length > 1) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: business,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr('النشاط التجاري'),
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
                  title: Text(tr('نشر البطاقة للعامة')),
                  subtitle: Text(
                    tr('يظهر الرابط ورمز QR للزبائن مباشرة بعد الحفظ.'),
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
                _shopSlug != null ? _shopOwnerSection() : _ownerSection(),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 4),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(
                    tr('خيارات متقدمة'),
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: kind,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr('نوع البطاقة'),
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
                        labelText: tr('الرابط المختصر · custom_slug'),
                        prefixIcon: const Icon(Icons.link),
                        helperText: tr('يُثبَّت بعد أول نشر لحماية البطاقة'),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => AppConfig.validSlug(v?.trim() ?? '')
                          ? null
                          : tr('3–63 حرفاً لاتينياً صغيراً وأرقاماً وشرطات'),
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
          child: Text(tr('إلغاء')),
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
          label: Text(busy ? tr('جارٍ الحفظ…') : tr('حفظ')),
        ),
      ],
    );
  }
}
