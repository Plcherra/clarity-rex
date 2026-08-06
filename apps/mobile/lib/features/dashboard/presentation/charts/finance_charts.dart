import 'package:flutter/material.dart';

import 'package:clarity/core/formatting/formatting.dart';
import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/dashboard/domain/dashboard_transaction_groups.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/theme/clarity_colors.dart';

import 'finance_chart_primitives.dart';

export 'finance_cash_flow_charts.dart';
export 'finance_chart_primitives.dart';
export 'finance_chart_range_switch.dart';

String _chartCategoryLabel(AppLocalizations l10n, String category) {
  if (isNeedsCategoryGroupKey(category)) {
    return l10n.dashboardNeedsCategoryLabel;
  }
  return category;
}

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

    return Column(
      children: [
        for (final item in top)
          _HorizontalAmountBar(
            label: _chartCategoryLabel(l10n, item.name),
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

class BiggestLeaksChart extends StatelessWidget {
  const BiggestLeaksChart({required this.leaks, this.onCategoryTap, super.key});

  final List<CategoryLeakStat> leaks;

  /// Opens the transactions behind a bar. Bars stay flat when this is null.
  final void Function(String category)? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (leaks.isEmpty) {
      return FinanceChartEmpty(
        message: l10n.dashboardChartNoSpendingPressure,
      );
    }

    final top = leaks.take(5).toList(growable: false);
    final maxAmount = top
        .map((item) => item.amountThisMonth)
        .fold<double>(0, (max, value) => value > max ? value : max);

    return Column(
      children: [
        for (final item in top)
          _HorizontalAmountBar(
            label: _chartCategoryLabel(l10n, item.name),
            amount: item.amountThisMonth,
            maxAmount: maxAmount,
            color: ClarityColors.financeSpending,
            onTap: onCategoryTap == null
                ? null
                : () => onCategoryTap!(item.name),
          ),
      ],
    );
  }
}

class BudgetVsSpentChart extends StatelessWidget {
  const BudgetVsSpentChart({required this.performance, super.key});

  final BudgetPerformanceSnapshot performance;

  @override
  Widget build(BuildContext context) {
    final categories = performance.categories.isNotEmpty
        ? performance.categories.take(6).toList(growable: false)
        : performance.topOverspendingCategories;
    if (categories.isEmpty) {
      return FinanceChartEmpty(
        message: context.l10n.dashboardChartNoBudgetCategories,
      );
    }

    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return Column(
      children: [
        for (final category in categories) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  category.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${formatMoney(category.spent)} / ${formatMoney(category.budgeted)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: category.budgeted <= 0
                  ? 0
                  : (category.spent / category.budgeted).clamp(0, 1.5),
              backgroundColor: colors.surfaceElevated,
              color: category.onTrack
                  ? colors.accent
                  : ClarityColors.financeNegative,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class IncomeSpendRatioChart extends StatelessWidget {
  const IncomeSpendRatioChart({
    required this.income,
    required this.spent,
    super.key,
  });

  final double income;
  final double spent;

  @override
  Widget build(BuildContext context) {
    if (income <= 0 && spent <= 0) {
      return FinanceChartEmpty(
        message: context.l10n.dashboardChartNoIncomeOrSpending,
      );
    }

    final total = income + spent;
    final incomeShare = total <= 0 ? 0.0 : income / total;
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                if (incomeShare > 0)
                  Expanded(
                    flex: (incomeShare * 100).round().clamp(1, 100),
                    child: ColoredBox(color: ClarityColors.financePositive),
                  ),
                if (incomeShare < 1)
                  Expanded(
                    flex: ((1 - incomeShare) * 100).round().clamp(1, 100),
                    child: ColoredBox(color: ClarityColors.financeSpending),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.dashboardChartIncomeSpendingSummary(
            formatMoney(income),
            formatMoney(spent),
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

class _HorizontalAmountBar extends StatelessWidget {
  const _HorizontalAmountBar({
    required this.label,
    required this.amount,
    required this.maxAmount,
    required this.color,
    this.onTap,
  });

  final String label;
  final double amount;
  final double maxAmount;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.clarityColors.textMuted;
    final fraction = maxAmount <= 0
        ? 0.0
        : (amount / maxAmount).clamp(0.0, 1.0);

    final bar = Padding(
      padding: EdgeInsets.fromLTRB(0, onTap == null ? 0 : 6, 0, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatMoney(amount),
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: fraction,
              backgroundColor: context.clarityColors.surfaceElevated,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return bar;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Semantics(
        button: true,
        label: context.l10n.dashboardChartCategoryDrilldownHint(label),
        child: bar,
      ),
    );
  }
}
