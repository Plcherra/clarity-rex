import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/dashboard/domain/dashboard_transaction_groups.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/theme/clarity_colors.dart';

import 'finance_chart_primitives.dart';

/// Spider chart of this month's top category spend, with an optional budget ring.
class CategorySpendRadarChart extends StatelessWidget {
  const CategorySpendRadarChart({
    required this.categories,
    this.budgetPerformance,
    super.key,
  });

  final List<CategorySpend> categories;
  final BudgetPerformanceSnapshot? budgetPerformance;

  static const _minAxes = 3;
  static const _maxAxes = 6;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final top = categories
        .where((item) => item.amount > 0)
        .take(_maxAxes)
        .toList(growable: false);
    if (top.length < _minAxes) {
      return FinanceChartEmpty(
        message: l10n.dashboardChartNoCategorySpending,
      );
    }

    final titles = [
      for (final item in top) _shortRadarLabel(l10n, item.name),
    ];
    final spent = [for (final item in top) item.amount];
    final budgeted = [
      for (final item in top) _budgetForCategory(item.name, budgetPerformance),
    ];
    final showBudget = budgeted.any((value) => value > 0);
    final maxValue = [
      ...spent,
      if (showBudget) ...budgeted,
    ].fold<double>(0, (max, value) => value > max ? value : max);
    // fl_chart radar needs a non-zero scale.
    final scaleMax = maxValue <= 0 ? 1.0 : maxValue;

    final colors = context.clarityColors;
    final spentColor = colors.accent;
    final budgetColor = colors.textSecondary;

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              tickCount: 4,
              ticksTextStyle: TextStyle(
                color: colors.textMuted,
                fontSize: 10,
              ),
              titleTextStyle: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              titlePositionPercentageOffset: 0.14,
              gridBorderData: BorderSide(
                color: colors.divider.withValues(alpha: 0.45),
              ),
              tickBorderData: BorderSide(
                color: colors.divider.withValues(alpha: 0.25),
              ),
              radarBorderData: BorderSide(
                color: colors.divider.withValues(alpha: 0.45),
              ),
              getTitle: (index, angle) => RadarChartTitle(
                text: titles[index],
                angle: angle,
              ),
              dataSets: [
                if (showBudget)
                  RadarDataSet(
                    fillColor: budgetColor.withValues(alpha: 0.08),
                    borderColor: budgetColor.withValues(alpha: 0.75),
                    borderWidth: 1.5,
                    entryRadius: 1.5,
                    dataEntries: [
                      for (final value in budgeted)
                        RadarEntry(
                          value: (value <= 0 ? 0 : value) / scaleMax * 100,
                        ),
                    ],
                  ),
                RadarDataSet(
                  fillColor: spentColor.withValues(alpha: 0.22),
                  borderColor: spentColor,
                  borderWidth: 2,
                  entryRadius: 2,
                  dataEntries: [
                    for (final value in spent)
                      RadarEntry(
                        value: (value <= 0 ? 0 : value) / scaleMax * 100,
                      ),
                  ],
                ),
              ],
            ),
            duration: Duration.zero,
          ),
        ),
        if (showBudget) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RadarLegendSwatch(
                color: spentColor,
                label: l10n.dashboardChartSpendRadarSpentLegend,
              ),
              const SizedBox(width: 16),
              _RadarLegendSwatch(
                color: budgetColor,
                label: l10n.dashboardChartSpendRadarBudgetLegend,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RadarLegendSwatch extends StatelessWidget {
  const _RadarLegendSwatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.35),
            border: Border.all(color: color, width: 1.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.clarityColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

double _budgetForCategory(
  String categoryName,
  BudgetPerformanceSnapshot? performance,
) {
  if (performance == null) return 0;
  final needle = categoryName.trim().toLowerCase();
  if (needle.isEmpty) return 0;
  for (final row in performance.categories) {
    if (row.displayLabel.trim().toLowerCase() == needle) {
      return row.budgeted;
    }
  }
  for (final row in performance.topOverspendingCategories) {
    if (row.displayLabel.trim().toLowerCase() == needle) {
      return row.budgeted;
    }
  }
  return 0;
}

String _shortRadarLabel(AppLocalizations l10n, String category) {
  if (isNeedsCategoryGroupKey(category)) {
    return l10n.dashboardNeedsCategoryLabel;
  }
  final cleaned = category.trim();
  if (cleaned.length <= 14) return cleaned;
  final slash = cleaned.indexOf('/');
  if (slash > 2 && slash <= 16) {
    return cleaned.substring(0, slash).trim();
  }
  return '${cleaned.substring(0, 12)}…';
}
