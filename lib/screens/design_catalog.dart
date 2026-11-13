import 'package:flutter/material.dart';

import '../core/card_themes.dart';
import '../core/i18n.dart';

/// Material icon for each shop sector (same meaning as the website's stamps).
IconData sectorIcon(String industry) => switch (industry) {
      'barber' => Icons.content_cut,
      'cafe' => Icons.local_cafe_outlined,
      'bakery' => Icons.bakery_dining_outlined,
      'carwash' => Icons.local_car_wash_outlined,
      'snack' => Icons.local_pizza_outlined,
      'gym' => Icons.fitness_center,
      'beauty' => Icons.auto_awesome,
      _ => Icons.star_outline,
    };

/// The member card the customer sees, drawn small in a design's colours.
class MiniLoyaltyCard extends StatelessWidget {
  const MiniLoyaltyCard({super.key, required this.design, required this.shopName, required this.industry});

  final LoyaltyDesign design;
  final String shopName;
  final String industry;

  @override
  Widget build(BuildContext context) {
    final d = design;
    return AspectRatio(
      aspectRatio: 1.586,
      child: LayoutBuilder(builder: (context, box) {
        final u = box.maxWidth / 100; // 1% of the card width
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5 * u),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [d.a, d.b]),
            border: Border.all(color: d.gold.withValues(alpha: 0.3)),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 6))],
          ),
          child: Stack(children: [
            // Decoration on the far side, away from the text.
            PositionedDirectional(
              end: -38 * u,
              top: 14 * u,
              child: Container(
                width: 76 * u,
                height: 76 * u,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: d.gold.withValues(alpha: 0.45), width: 1.2),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(6 * u, 5.5 * u, 6 * u, 5 * u),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      width: 10 * u,
                      height: 10 * u,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2.6 * u),
                        border: Border.all(color: d.gold.withValues(alpha: 0.6)),
                        color: d.gold.withValues(alpha: 0.1),
                      ),
                      child: Icon(sectorIcon(industry), size: 6 * u, color: d.gold),
                    ),
                    const Spacer(),
                    Container(
                      width: 10 * u,
                      height: 7.5 * u,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1.5 * u),
                        gradient: const LinearGradient(colors: [Color(0xFFF3DFA0), Color(0xFFC9A24A), Color(0xFFF0D88C)]),
                      ),
                    ),
                    SizedBox(width: 2 * u),
                    Icon(Icons.contactless_outlined, size: 7 * u, color: d.gold),
                  ]),
                  Text(
                    shopName.isEmpty ? 'TapMaroc' : shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: d.gold, fontSize: 9 * u, fontWeight: FontWeight.w800, fontFamily: 'serif'),
                  ),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Text(tr('اسم الزبون'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: d.text, fontSize: 4.6 * u, fontWeight: FontWeight.w800)),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 3 * u, vertical: 0.8 * u),
                      decoration: BoxDecoration(color: d.gold, borderRadius: BorderRadius.circular(99)),
                      child: Text('3 / 5',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(color: d.ink, fontSize: 4 * u, fontWeight: FontWeight.w900)),
                    ),
                  ]),
                ],
              ),
            ),
          ]),
        );
      }),
    );
  }
}

/// The design catalog: filter chips and a row of member cards to pick from.
class DesignPicker extends StatefulWidget {
  const DesignPicker({super.key, required this.value, required this.onChanged, required this.shopName, required this.industry});

  final String value;
  final ValueChanged<String> onChanged;
  final String shopName;
  final String industry;

  @override
  State<DesignPicker> createState() => _DesignPickerState();
}

class _DesignPickerState extends State<DesignPicker> {
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final lang = appLang.value;
    final scheme = Theme.of(context).colorScheme;
    bool keep(LoyaltyDesign d) => switch (filter) {
          'dark' => d.premium && !d.light,
          'light' => d.premium && d.light,
          'classic' => !d.premium,
          _ => true,
        };
    final list = cardThemes.where(keep).toList()
      ..sort((x, y) => x.key == widget.value ? -1 : y.key == widget.value ? 1 : (y.premium ? 1 : 0) - (x.premium ? 1 : 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('تصميم بطاقة الولاء'), style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(tr('هذا ما يراه الزبائن على هاتفهم وفي Google Wallet. يمكن لصاحب المحل تغييره لاحقاً.'),
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, children: [
        for (final f in const ['all', 'dark', 'light', 'classic'])
          ChoiceChip(
            label: Text(switch (f) {
              'dark' => tr('فاخر غامق'),
              'light' => tr('فاتح وناعم'),
              'classic' => tr('كلاسيكي'),
              _ => tr('الكل'),
            }),
            selected: filter == f,
            onSelected: (_) => setState(() => filter = f),
          ),
      ]),
      const SizedBox(height: 10),
      SizedBox(
        height: 168,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final d = list[i];
            final on = d.key == widget.value;
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => widget.onChanged(d.key),
              child: Container(
                width: 200,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: on ? scheme.primary : Colors.transparent, width: 2),
                  color: on ? scheme.primary.withValues(alpha: 0.08) : null,
                ),
                child: Column(children: [
                  MiniLoyaltyCard(design: d, shopName: widget.shopName, industry: widget.industry),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: Text(d.name(lang),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    if (on)
                      Icon(Icons.check_circle, size: 18, color: scheme.primary)
                    else if (d.premium)
                      Text(tr('بريميوم'), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ]),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
