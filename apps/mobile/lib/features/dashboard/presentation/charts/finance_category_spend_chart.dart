import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/dashboard/domain/dashboard_transaction_groups.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/theme/clarity_colors.dart';

import 'finance_chart_primitives.dart';

class CategorySpendChart extends StatelessWidget {
  const CategorySpendChart({
    required this.categories,
    this.onCategoryTap,
    super.key,
  });

  final List<CategorySpend> categories;

  /// Opens the transactions behind a bar. Bars stay flat when this is null.
  final void Function(String category)? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (categories.isEmpty) {
      return FinanceChartEmpty(
        message: l10n.dashboardChartNoCategorySpending,
      );
    }

    final top = categories.take(5).toList(growable: false);
    final maxAmount = top
        .map((item) => item.amount)
        .fold<double>(0, (max, value) => value > max ? value : max);
    final sliceColors = categorySpendSliceColors(context);

    return Column(
      children: [
        for (var i = 0; i < top.length; i++)
          FinanceHorizontalAmountBar(
            label: categorySpendLabel(l10n, top[i].name),
            amount: top[i].amount,
            maxAmount: maxAmount,
            color: sliceColors[i % sliceColors.length],
            onTap: onCategoryTap == null
                ? null
                : () => onCategoryTap!(top[i].name),
          ),
      ],
    );
  }
}

class CategorySpendPieChart extends StatelessWidget {
  const CategorySpendPieChart({
    required this.categories,
    this.onCategoryTap,
    super.key,
  });

  final List<CategorySpend> categories;
  final void Function(String category)? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (categories.isEmpty) {
      return FinanceChartEmpty(
        message: l10n.dashboardChartNoCategorySpending,
      );
    }

    final top = categories.take(5).toList(growable: false);
    final sliceColors = categorySpendSliceColors(context);
    return SizedBox(
      height: financeChartHeight(context, compact: 180),
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 28,
          pieTouchData: PieTouchData(
            enabled: onCategoryTap != null,
            touchCallback: (event, response) {
              if (onCategoryTap == null || event is! FlTapUpEvent) {
                return;
              }
              final index =
                  response?.touchedSection?.touchedSectionIndex ?? -1;
              if (index < 0 || index >= top.length) return;
              onCategoryTap!(top[index].name);
            },
          ),
          sections: [
            for (var i = 0; i < top.length; i++)
              PieChartSectionData(
                value: top[i].amount,
                color: sliceColors[i % sliceColors.length],
                radius: 52,
                title: '',
              ),
          ],
        ),
      ),
    );
  }
}

String categorySpendLabel(AppLocalizations l10n, String category) {
  if (isNeedsCategoryGroupKey(category)) {
    return l10n.dashboardNeedsCategoryLabel;
  }
  return category;
}

List<Color> categorySpendSliceColors(BuildContext context) {
  final colors = context.clarityColors;
  return [
    colors.accent,
    ClarityColors.financeSpending,
    colors.accentStrong,
    ClarityColors.financePositive,
    colors.textSecondary,
  ];
}
