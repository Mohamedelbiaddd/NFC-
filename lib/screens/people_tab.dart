import 'package:flutter/material.dart';
import '../core/i18n.dart';

import '../core/people.dart';
import '../core/repository.dart';
import '../core/theme.dart';

/// The main "people" list: search, tap to select, then two large actions at the
/// bottom (QR label and NFC card) exactly where a field worker expects them.
class PeopleTab extends StatefulWidget {
  const PeopleTab({
    super.key,
    required this.profiles,
    required this.loading,
    required this.canEdit,
    required this.canDelete,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onQr,
    required this.onWrite,
    required this.onPreview,
    required this.onRefresh,
    this.onShopPassword,
    this.scans = const {},
    this.totalScans = 0,
  });

  final List<Json> profiles;
  final bool loading;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onCreate;
  final void Function(Json profile) onEdit;
  final void Function(Json profile) onDelete;
  final void Function(Json profile) onQr;
  final void Function(Json profile) onWrite;
  final void Function(Json profile) onPreview;
  final Future<void> Function() onRefresh;

  /// For a loyalty card linked to a shop: new owner password for that shop.
  final void Function(Json profile, String shopSlug)? onShopPassword;
  final Map<String, int> scans;
  final int totalScans;

  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> {
  final search = TextEditingController();
  String? selectedId;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<Json> get filtered {
    final query = search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.profiles;
    return widget.profiles.where((p) {
      final haystack = [
        personName(p),
        personTitle(p),
        personSlug(p),
        personPhone(p),
        personEmail(p),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Json? get selected {
    for (final profile in widget.profiles) {
      if (profile['id'] == selectedId) return profile;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final items = filtered;
    final published = widget.profiles.where(personPublished).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: tr('ابحث بالاسم أو الهاتف أو الرابط…'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        suffixIcon: search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: tr('مسح'),
                                onPressed: () => setState(search.clear),
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: tr('تحديث'),
                    onPressed: widget.loading ? null : widget.onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Pill(
                    trf('{0} شخص', [widget.profiles.length]),
                    icon: Icons.people_alt_outlined,
                  ),
                  const SizedBox(width: 8),
                  Pill(
                    trf('{0} منشور', [published]),
                    color: AppColors.success,
                    icon: Icons.public,
                  ),
                  const SizedBox(width: 8),
                  Pill(
                    trf('{0} مشاهدة', [widget.totalScans]),
                    color: AppColors.primarySoft,
                    icon: Icons.visibility_outlined,
                  ),
                  const Spacer(),
                  if (widget.canEdit)
                    TextButton.icon(
                      onPressed: widget.onCreate,
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: Text(tr('شخص جديد')),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.loading && widget.profiles.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: items.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const SizedBox(height: 20),
                            EmptyState(
                              icon: Icons.person_search_rounded,
                              title: widget.profiles.isEmpty
                                  ? tr('لا يوجد أشخاص بعد')
                                  : tr('لا نتائج مطابقة'),
                              text: widget.profiles.isEmpty
                                  ? tr('أضف أول شخص، ثم اكتب بطاقة NFC أو اطبع رمز QR من نفس الشاشة.')
                                  : tr('جرّب البحث باسم آخر أو رقم هاتف.'),
                              action: widget.canEdit && widget.profiles.isEmpty
                                  ? FilledButton.icon(
                                      onPressed: widget.onCreate,
                                      icon: const Icon(Icons.add_rounded),
                                      label: Text(tr('إضافة شخص')),
                                    )
                                  : null,
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final profile = items[index];
                            return _personCard(profile);
                          },
                        ),
                ),
        ),
        if (selected != null) _actionBar(selected!),
      ],
    );
  }

  Widget _personCard(Json profile) {
    final isSelected = profile['id'] == selectedId;
    final image = personImage(profile);
    final phone = personPhone(profile);
    final isPublished = personPublished(profile);
    return SurfaceCard(
      highlight: isSelected,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => setState(
        () => selectedId = isSelected ? null : profile['id'] as String?,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: image.isEmpty
                ? Center(
                    child: Text(
                      personInitial(profile),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primarySoft,
                      ),
                    ),
                  )
                : Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        personInitial(profile),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primarySoft,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        personName(profile),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!isPublished) ...[
                      const SizedBox(width: 6),
                      Pill(tr('مسودة'), color: AppColors.warning),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (phone.isNotEmpty) phone,
                    kindLabel(profile),
                    '/p/${personSlug(profile)}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if ((widget.scans[profile['id']] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    size: 13,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${widget.scans[profile['id']]}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          PopupMenuButton<String>(
            tooltip: tr('خيارات'),
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  widget.onEdit(profile);
                case 'qr':
                  widget.onQr(profile);
                case 'write':
                  widget.onWrite(profile);
                case 'preview':
                  widget.onPreview(profile);
                case 'delete':
                  widget.onDelete(profile);
                case 'shop_password':
                  final slug = loyaltyShopSlug(profile);
                  if (slug != null) widget.onShopPassword?.call(profile, slug);
              }
            },
            itemBuilder: (context) => [
              if (widget.canEdit)
                PopupMenuItem(value: 'edit', child: Text(tr('تعديل'))),
              PopupMenuItem(value: 'qr', child: Text(tr('رمز QR'))),
              PopupMenuItem(value: 'write', child: Text(tr('ربط بطاقة NFC'))),
              PopupMenuItem(value: 'preview', child: Text(tr('فتح الرابط'))),
              if (widget.onShopPassword != null && loyaltyShopSlug(profile) != null)
                PopupMenuItem(
                  value: 'shop_password',
                  child: Text(tr('🔑 تغيير كلمة مرور صاحب المحل')),
                ),
              if (widget.canDelete) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    tr('حذف'),
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBar(Json profile) {
    final phone = personPhone(profile);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        personName(profile),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        phone.isEmpty ? '/p/${personSlug(profile)}' : phone,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr('إغلاق'),
                  onPressed: () => setState(() => selectedId = null),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => widget.onWrite(profile),
                    icon: const Icon(Icons.nfc_rounded, size: 20),
                    label: Text(tr('ربط البطاقة')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onQr(profile),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                    label: Text(tr('رمز QR')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The shop slug when this card is a loyalty card pointing at one of our
/// shop pages (…/c/<slug>), otherwise null.
String? loyaltyShopSlug(Json profile) {
  if ('${profile['kind']}' != 'loyalty') return null;
  final data = profile['data'];
  final url = data is Map ? '${data['loyalty_url'] ?? ''}' : '';
  final match = RegExp(r'/c/([a-z0-9]+(?:-[a-z0-9]+)*)/?$').firstMatch(url);
  return match?.group(1);
}
