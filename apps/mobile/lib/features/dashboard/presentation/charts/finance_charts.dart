import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'package:clarity/core/formatting/formatting.dart';
import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/transactions/domain/bank_statement_monthly.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/theme/clarity_colors.dart';

class MonthlyCashFlowChart extends StatelessWidget {
  const MonthlyCashFlowChart({required this.monthlyGroups, super.key});

  final List<MonthlyBankGroup> monthlyGroups;

  @override
  Widget build(BuildContext context) {
    if (monthlyGroups.isEmpty) {
      return _FinanceChartEmpty(
        message: context.l10n.dashboardChartConnectAccountsCashFlow,
      );
    }

    final recent = trimFinanceChartMonths(monthlyGroups);
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final labels = recent.map((group) => _monthLabel(l10n, group)).toList();
    final incomeValues = recent.map(_incomeForGroup).toList();
    final spendValues = recent.map(_spendForGroup).toList();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: financeChartMaxY([...incomeValues, ...spendValues]),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: colors.divider.withValues(alpha: 0.35),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final index = value.round();
                  if (index < 0 || index >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    labels[index],
                    style: TextStyle(color: colors.textMuted, fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < recent.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 4,
                barRods: [
                  BarChartRodData(
                    toY: incomeValues[i],
                    color: ClarityColors.financePositive,
                    width: 8,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  BarChartRodData(
                    toY: spendValues[i],
                    color: ClarityColors.financeSpending,
                    width: 8,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class CategorySpendChart extends StatelessWidget {
  const CategorySpendChart({required this.categories, super.key});

  final List<CategorySpend> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return _FinanceChartEmpty(
        message: context.l10n.dashboardChartNoCategorySpending,
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
            label: item.name,
            amount: item.amount,
            maxAmount: maxAmount,
            color: context.clarityColors.accent,
          ),
      ],
    );
  }
}

class BiggestLeaksChart extends StatelessWidget {
  const BiggestLeaksChart({required this.leaks, super.key});

  final List<CategoryLeakStat> leaks;

  @override
  Widget build(BuildContext context) {
    if (leaks.isEmpty) {
      return _FinanceChartEmpty(
        message: context.l10n.dashboardChartNoSpendingPressure,
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
            label: item.name,
            amount: item.amountThisMonth,
            maxAmount: maxAmount,
            color: ClarityColors.financeSpending,
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
      return _FinanceChartEmpty(
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

class SixMonthSpendTrendChart extends StatelessWidget {
  const SixMonthSpendTrendChart({required this.monthlyGroups, super.key});

  final List<MonthlyBankGroup> monthlyGroups;

  @override
  Widget build(BuildContext context) {
    if (monthlyGroups.isEmpty) {
      return _FinanceChartEmpty(
        message: context.l10n.dashboardChartNoSpendingHistory,
      );
    }

    final recent = trimFinanceChartMonths(monthlyGroups);
    final spendValues = recent.map(_spendForGroup).toList();
    final l10n = context.l10n;
    final labels = recent.map((group) => _monthLabel(l10n, group)).toList();
    final colors = context.clarityColors;
    final spots = [
      for (var i = 0; i < spendValues.length; i++)
        FlSpot(i.toDouble(), spendValues[i]),
    ];

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: financeChartMaxY(spendValues),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: colors.divider.withValues(alpha: 0.35),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final index = value.round();
                  if (index < 0 || index >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    labels[index],
                    style: TextStyle(color: colors.textMuted, fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: ClarityColors.financeSpending,
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
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
      return _FinanceChartEmpty(
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

class _FinanceChartEmpty extends StatelessWidget {
  const _FinanceChartEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.clarityColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _HorizontalAmountBar extends StatelessWidget {
  const _HorizontalAmountBar({
    required this.label,
    required this.amount,
    required this.maxAmount,
    required this.color,
  });

  final String label;
  final double amount;
  final double maxAmount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxAmount <= 0 ? 0.0 : (amount / maxAmount).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.clarityColors.textMuted,
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
  }
}

String _monthLabel(AppLocalizations l10n, MonthlyBankGroup group) {
  final parts = group.yearMonth.split('-');
  if (parts.length != 2) {
    return group.yearMonth;
  }
  final month = int.tryParse(parts[1]) ?? 0;
  if (month < 1 || month > 12) {
    return group.yearMonth;
  }
  return switch (month) {
    1 => l10n.commonMonthShortJan,
    2 => l10n.commonMonthShortFeb,
    3 => l10n.commonMonthShortMar,
    4 => l10n.commonMonthShortApr,
    5 => l10n.commonMonthShortMay,
    6 => l10n.commonMonthShortJun,
    7 => l10n.commonMonthShortJul,
    8 => l10n.commonMonthShortAug,
    9 => l10n.commonMonthShortSep,
    10 => l10n.commonMonthShortOct,
    11 => l10n.commonMonthShortNov,
    12 => l10n.commonMonthShortDec,
    _ => l10n.commonMonthShortOld,
  };
}

double _incomeForGroup(MonthlyBankGroup group) {
  var total = 0.0;
  for (final line in group.transactions) {
    if (line.transaction.amount > 0) {
      total += line.transaction.amount;
    }
  }
  return total;
}

double _spendForGroup(MonthlyBankGroup group) {
  var total = 0.0;
  for (final line in group.transactions) {
    if (line.transaction.amount < 0) {
      total += -line.transaction.amount;
    }
  }
  return total;
}

@visibleForTesting
List<T> trimFinanceChartMonths<T>(List<T> items) {
  if (items.length <= 6) {
    return items;
  }
  return items.sublist(items.length - 6);
}

@visibleForTesting
double financeChartMaxY(Iterable<double> values) {
  final maxY = values.fold<double>(
    0,
    (max, value) => value > max ? value : max,
  );
  return maxY <= 0 ? 1 : maxY * 1.15;
}
