import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../theme/clarity_shadows.dart';
import '../domain/budget_models.dart';

class BudgetsHeader extends StatelessWidget {
  const BudgetsHeader({
    super.key,
    required this.selectedType,
    required this.selectedPeriodKey,
    required this.keys,
    required this.monthlyLabel,
    required this.weeklyLabel,
    required this.weeklyRangeLabel,
    required this.customStartLabel,
    required this.customEndLabel,
    required this.onPeriodTypeChanged,
    required this.onPickMonthly,
    required this.onPickWeekly,
    required this.onPickCustomStart,
    required this.onPickCustomEnd,
    required this.compactButtonStyle,
  });

  final BudgetPeriodType selectedType;
  final String selectedPeriodKey;
  final List<String> keys;
  final String monthlyLabel;
  final String weeklyLabel;
  final String weeklyRangeLabel;
  final String customStartLabel;
  final String customEndLabel;
  final ValueChanged<BudgetPeriodType> onPeriodTypeChanged;
  final VoidCallback onPickMonthly;
  final VoidCallback onPickWeekly;
  final VoidCallback onPickCustomStart;
  final VoidCallback onPickCustomEnd;
  final ButtonStyle compactButtonStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
        boxShadow: ClarityShadows.panel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BudgetPeriodToggle(
            selectedType: selectedType,
            monthlyLabel: l10n.commonMonthly,
            weeklyLabel: l10n.commonWeekly,
            customLabel: l10n.commonCustom,
            onChanged: onPeriodTypeChanged,
          ),
          const SizedBox(height: 10),
          if (selectedType == BudgetPeriodType.monthly)
            keys.isEmpty
                ? Text(
                    l10n.budgetsHeaderNoMonthsAvailable,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.56),
                    ),
                  )
                : OutlinedButton.icon(
                    style: compactButtonStyle,
                    onPressed: onPickMonthly,
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: Text(monthlyLabel),
                  ),
          if (selectedType == BudgetPeriodType.weekly) ...[
            OutlinedButton.icon(
              style: compactButtonStyle,
              onPressed: onPickWeekly,
              icon: const Icon(Icons.date_range_rounded, size: 16),
              label: Text(weeklyLabel),
            ),
            const SizedBox(height: 6),
            Text(
              weeklyRangeLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.58),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (selectedType == BudgetPeriodType.custom)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: compactButtonStyle,
                    onPressed: onPickCustomStart,
                    icon: const Icon(Icons.calendar_today_rounded, size: 15),
                    label: Text(
                      customStartLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: compactButtonStyle,
                    onPressed: onPickCustomEnd,
                    icon: const Icon(Icons.event_rounded, size: 15),
                    label: Text(
                      customEndLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BudgetPeriodToggle extends StatelessWidget {
  const _BudgetPeriodToggle({
    required this.selectedType,
    required this.monthlyLabel,
    required this.weeklyLabel,
    required this.customLabel,
    required this.onChanged,
  });

  final BudgetPeriodType selectedType;
  final String monthlyLabel;
  final String weeklyLabel;
  final String customLabel;
  final ValueChanged<BudgetPeriodType> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            _BudgetPeriodToggleSegment(
              label: monthlyLabel,
              selected: selectedType == BudgetPeriodType.monthly,
              onTap: () => onChanged(BudgetPeriodType.monthly),
            ),
            _BudgetPeriodToggleSegment(
              label: weeklyLabel,
              selected: selectedType == BudgetPeriodType.weekly,
              onTap: () => onChanged(BudgetPeriodType.weekly),
            ),
            _BudgetPeriodToggleSegment(
              label: customLabel,
              selected: selectedType == BudgetPeriodType.custom,
              onTap: () => onChanged(BudgetPeriodType.custom),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetPeriodToggleSegment extends StatelessWidget {
  const _BudgetPeriodToggleSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Expanded(
      child: Material(
        color: selected
            ? cs.surface
            : Colors.transparent,
        elevation: selected ? 0.5 : 0,
        shadowColor: cs.shadow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
