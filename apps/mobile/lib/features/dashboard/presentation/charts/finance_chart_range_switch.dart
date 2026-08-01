import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/theme/clarity_colors.dart';

/// Windows a finance chart can show, in months.
const financeChartRanges = [3, 6, 12];

const financeChartDefaultRange = 6;

/// Compact 3M / 6M / 1Y control that sits above a single chart.
class FinanceChartRangeSwitch extends StatelessWidget {
  const FinanceChartRangeSwitch({
    required this.months,
    required this.onChanged,
    super.key,
  });

  final int months;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;

    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        label: l10n.financeChartRangeLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final range in financeChartRanges)
                  _RangeChip(
                    label: financeChartRangeLabel(l10n, range),
                    selected: range == months,
                    onTap: () => onChanged(range),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String financeChartRangeLabel(AppLocalizations l10n, int months) {
  return switch (months) {
    3 => l10n.financeChartRange3Months,
    12 => l10n.financeChartRange12Months,
    _ => l10n.financeChartRange6Months,
  };
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? colors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? colors.background : colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
