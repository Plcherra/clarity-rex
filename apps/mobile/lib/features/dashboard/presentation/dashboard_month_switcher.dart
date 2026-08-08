import 'package:flutter/material.dart';

import '../../../core/formatting/formatting.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../theme/clarity_colors.dart';
import '../../transactions/domain/bank_statement_monthly.dart';
import '../domain/dashboard_available_months.dart';

/// Prev / next + tappable month label for Overview month-scoped charts.
class DashboardMonthSwitcher extends StatelessWidget {
  const DashboardMonthSwitcher({
    required this.selectedMonth,
    required this.availableYearMonths,
    required this.onMonthSelected,
    super.key,
  });

  final DateTime selectedMonth;
  final List<String> availableYearMonths;
  final ValueChanged<DateTime> onMonthSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.clarityColors;
    final selectedKey = yearMonthKey(selectedMonth);
    final months = availableYearMonths.isEmpty
        ? <String>[selectedKey]
        : availableYearMonths;
    final index = months.indexOf(selectedKey);
    final effectiveIndex = index >= 0 ? index : 0;
    final canGoNewer = effectiveIndex > 0;
    final canGoOlder = effectiveIndex < months.length - 1;
    final label = formatYearMonthLabel(
      months[effectiveIndex.clamp(0, months.length - 1)],
    );

    return Row(
      children: [
        IconButton(
          tooltip: l10n.dashboardMonthPreviousTooltip,
          onPressed: canGoOlder
              ? () {
                  final next = parseDashboardYearMonth(months[effectiveIndex + 1]);
                  if (next != null) onMonthSelected(next);
                }
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: TextButton(
            onPressed: months.length <= 1
                ? null
                : () => _pickMonth(context, months, selectedKey),
            style: TextButton.styleFrom(
              foregroundColor: colors.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.dashboardMonthNextTooltip,
          onPressed: canGoNewer
              ? () {
                  final next = parseDashboardYearMonth(months[effectiveIndex - 1]);
                  if (next != null) onMonthSelected(next);
                }
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Future<void> _pickMonth(
    BuildContext context,
    List<String> months,
    String selectedKey,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: months.length,
            itemBuilder: (context, index) {
              final key = months[index];
              final selected = key == selectedKey;
              return ListTile(
                title: Text(formatYearMonthLabel(key)),
                trailing: selected
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                selected: selected,
                onTap: () => Navigator.of(sheetContext).pop(key),
              );
            },
          ),
        );
      },
    );
    if (picked == null || picked == selectedKey) return;
    final month = parseDashboardYearMonth(picked);
    if (month != null) onMonthSelected(month);
  }
}
