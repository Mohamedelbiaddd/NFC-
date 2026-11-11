import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/theme.dart';

/// Asks how long a payment covers: 1 / 3 / 6 months, 1 year, or a custom
/// number of months (1–36). Returns null when cancelled.
Future<int?> pickPaidMonths(BuildContext context, String name) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _PayMonthsSheet(name: name),
  );
}

/// Snack text for a recorded payment.
String paidMonthsLabel(int months) => months == 12
    ? tr('سنة')
    : months == 24
        ? tr('سنتان')
        : months == 1
            ? tr('شهر')
            : trf('{0} أشهر', [months]);

class _PayMonthsSheet extends StatefulWidget {
  const _PayMonthsSheet({required this.name});
  final String name;

  @override
  State<_PayMonthsSheet> createState() => _PayMonthsSheetState();
}

class _PayMonthsSheetState extends State<_PayMonthsSheet> {
  int months = 1;

  @override
  Widget build(BuildContext context) {
    const presets = [1, 3, 6, 12];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(trf('💵 تسجيل دفع لـ «{0}»', [widget.name]),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 4),
          Text(tr('اختر المدة التي دفعها:'), style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: [
              for (final m in presets)
                Material(
                  color: months == m ? AppColors.success.withValues(alpha: 0.22) : AppColors.surfaceHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: months == m ? AppColors.success : Colors.transparent,
                      width: 1.6,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => months = m),
                    child: Center(
                      child: Text(paidMonthsLabel(m),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Any other period, month by month.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(child: Text(tr('مدة أخرى'), style: const TextStyle(fontWeight: FontWeight.w600))),
                IconButton(
                  onPressed: months > 1 ? () => setState(() => months--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(
                  width: 74,
                  child: Text(paidMonthsLabel(months),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: months < 36 ? () => setState(() => months++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () => Navigator.pop(context, months),
            icon: const Icon(Icons.check_rounded),
            label: Text(trf('تأكيد الدفع: {0}', [paidMonthsLabel(months)])),
          ),
        ],
      ),
    );
  }
}
