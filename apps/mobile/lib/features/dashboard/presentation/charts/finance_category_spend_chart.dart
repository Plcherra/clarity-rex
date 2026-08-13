import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:clarity/core/formatting/formatting.dart';
import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/dashboard/domain/dashboard_transaction_groups.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/theme/clarity_colors.dart';

import 'finance_chart_primitives.dart';

const _categoryViewRotateEvery = Duration(seconds: 5);

class CategorySpendChart extends StatefulWidget {
  const CategorySpendChart({
    required this.categories,
    this.onCategoryTap,
    super.key,
  });

  final List<CategorySpend> categories;

  /// Opens the transactions behind a slice or bar.
  final void Function(String category)? onCategoryTap;

  @override
  State<CategorySpendChart> createState() => _CategorySpendChartState();
}

class _CategorySpendChartState extends State<CategorySpendChart> {
  var _showPie = false;
  Timer? _rotateTimer;

  @override
  void initState() {
    super.initState();
    _restartRotateTimer();
  }

  @override
  void dispose() {
    _rotateTimer?.cancel();
    super.dispose();
  }

  void _restartRotateTimer() {
    _rotateTimer?.cancel();
    _rotateTimer = Timer.periodic(_categoryViewRotateEvery, (_) {
      if (!mounted || widget.categories.isEmpty) return;
      setState(() => _showPie = !_showPie);
    });
  }

  void _toggleView() {
    setState(() => _showPie = !_showPie);
    _restartRotateTimer();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (widget.categories.isEmpty) {
      return FinanceChartEmpty(
        message: l10n.dashboardChartNoCategorySpending,
      );
    }

    final top = widget.categories.take(5).toList(growable: false);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message: l10n.dashboardChartToggleCategoryView,
            child: GestureDetector(
              onTap: _toggleView,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  _showPie
                      ? Icons.bar_chart_rounded
                      : Icons.pie_chart_outline_rounded,
                  size: 18,
                  color: context.clarityColors.textMuted,
                ),
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _showPie
              ? _CategorySpendPie(
                  key: const ValueKey('pie'),
                  categories: top,
                  onCategoryTap: widget.onCategoryTap,
                )
              : _CategorySpendBars(
                  key: const ValueKey('bars'),
                  categories: top,
                  onCategoryTap: widget.onCategoryTap,
                ),
        ),
      ],
    );
  }
}

class _CategorySpendBars extends StatelessWidget {
  const _CategorySpendBars({
    required this.categories,
    this.onCategoryTap,
    super.key,
  });

  final List<CategorySpend> categories;
  final void Function(String category)? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxAmount = categories
        .map((item) => item.amount)
        .fold<double>(0, (max, value) => value > max ? value : max);
    return Column(
      children: [
        for (final item in categories)
          FinanceHorizontalAmountBar(
            label: _categoryLabel(l10n, item.name),
            amount: item.amount,
            maxAmount: maxAmount,
            color: context.clarityColors.accent,
            onTap: onCategoryTap == null
                ? null
                : () => onCategoryTap!(item.name),
          ),
      ],
    );
  }
}

class _CategorySpendPie extends StatelessWidget {
  const _CategorySpendPie({
    required this.categories,
    this.onCategoryTap,
    super.key,
  });

  final List<CategorySpend> categories;
  final void Function(String category)? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sliceColors = _sliceColors(context);
    return Column(
      children: [
        SizedBox(
          height: financeChartHeight(context, compact: 180),
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 28,
              pieTouchData: PieTouchData(
                enabled: onCategoryTap != null,
                touchCallback: (event, response) {
                  if (onCategoryTap == null || !event.isInterestedForInteractions) {
                    return;
                  }
                  final index =
                      response?.touchedSection?.touchedSectionIndex ?? -1;
                  if (index < 0 || index >= categories.length) return;
                  onCategoryTap!(categories[index].name);
                },
              ),
              sections: [
                for (var i = 0; i < categories.length; i++)
                  PieChartSectionData(
                    value: categories[i].amount,
                    color: sliceColors[i % sliceColors.length],
                    radius: 52,
                    title: '',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (var i = 0; i < categories.length; i++)
              _PieLegendChip(
                color: sliceColors[i % sliceColors.length],
                label: _categoryLabel(l10n, categories[i].name),
                amount: categories[i].amount,
                onTap: onCategoryTap == null
                    ? null
                    : () => onCategoryTap!(categories[i].name),
              ),
          ],
        ),
      ],
    );
  }
}

class _PieLegendChip extends StatelessWidget {
  const _PieLegendChip({
    required this.color,
    required this.label,
    required this.amount,
    this.onTap,
  });

  final Color color;
  final String label;
  final double amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ${formatMoney(amount)}',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: child,
      ),
    );
  }
}

String _categoryLabel(AppLocalizations l10n, String category) {
  if (isNeedsCategoryGroupKey(category)) {
    return l10n.dashboardNeedsCategoryLabel;
  }
  return category;
}

List<Color> _sliceColors(BuildContext context) {
  final colors = context.clarityColors;
  return [
    colors.accent,
    ClarityColors.financeSpending,
    colors.accentStrong,
    ClarityColors.financePositive,
    colors.textSecondary,
  ];
}
