import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:clarity/core/formatting/formatting.dart';
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

class CategorySpendPieChart extends StatefulWidget {
  const CategorySpendPieChart({
    required this.categories,
    this.onCategoryTap,
    super.key,
  });

  final List<CategorySpend> categories;
  final void Function(String category)? onCategoryTap;

  @override
  State<CategorySpendPieChart> createState() => _CategorySpendPieChartState();
}

class _CategorySpendPieChartState extends State<CategorySpendPieChart> {
  int _hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (widget.categories.isEmpty) {
      return FinanceChartEmpty(
        message: l10n.dashboardChartNoCategorySpending,
      );
    }

    final top = widget.categories.take(5).toList(growable: false);
    final total = top.fold<double>(0, (sum, item) => sum + item.amount);
    final sliceColors = categorySpendSliceColors(context);
    final hovered =
        _hoveredIndex >= 0 && _hoveredIndex < top.length
        ? top[_hoveredIndex]
        : null;
    return SizedBox(
      height: financeChartHeight(context, compact: 180),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 44,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  final index =
                      response?.touchedSection?.touchedSectionIndex ?? -1;
                  final inside =
                      event.isInterestedForInteractions &&
                      index >= 0 &&
                      index < top.length;
                  final next = inside ? index : -1;
                  if (next != _hoveredIndex) {
                    setState(() => _hoveredIndex = next);
                  }
                  if (widget.onCategoryTap == null ||
                      event is! FlTapUpEvent ||
                      !inside) {
                    return;
                  }
                  widget.onCategoryTap!(top[index].name);
                },
              ),
              sections: [
                for (var i = 0; i < top.length; i++)
                  PieChartSectionData(
                    value: top[i].amount,
                    color: sliceColors[i % sliceColors.length],
                    radius: i == _hoveredIndex ? 50 : 44,
                    title: '',
                  ),
              ],
            ),
          ),
          if (hovered != null)
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _SliceDetail(
                  label: categorySpendLabel(l10n, hovered.name),
                  amount: hovered.amount,
                  total: total,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SliceDetail extends StatelessWidget {
  const _SliceDetail({
    required this.label,
    required this.amount,
    required this.total,
  });

  final String label;
  final double amount;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          categorySpendSliceShare(amount: amount, total: total),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: context.clarityColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String categorySpendSliceShare({
  required double amount,
  required double total,
}) {
  final percent = total <= 0 ? 0 : (amount / total * 100).round();
  return '${formatMoney(amount)} · $percent%';
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
