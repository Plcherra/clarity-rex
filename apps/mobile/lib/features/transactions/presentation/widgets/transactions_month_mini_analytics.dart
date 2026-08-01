import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/formatting/formatting.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../dashboard/domain/dashboard_snapshot.dart';
import '../../../dashboard/domain/monthly_cash_flow_series.dart';
import '../../../dashboard/presentation/charts/finance_charts.dart';
import '../../../../theme/clarity_colors.dart';
import '../../../../theme/clarity_radius.dart';
import '../../../../widgets/clarity_card.dart';

/// Compact dashboard-month summary for the transactions section.
///
/// Uses [DashboardSnapshot] fields only — no second aggregation path.
class TransactionsMonthMiniAnalytics extends StatelessWidget {
  const TransactionsMonthMiniAnalytics({
    required this.snapshot,
    super.key,
  });

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final hasActivity =
        snapshot.spentThisMonth > 0 ||
        snapshot.incomeThisMonth > 0 ||
        snapshot.topCategories.isNotEmpty ||
        snapshot.monthlyGroups.isNotEmpty;

    if (!hasActivity) {
      return const SizedBox.shrink();
    }

    final topCategories = snapshot.topCategories.take(3).toList(growable: false);
    final sparklineValues = _sparklineSpendValues(snapshot.monthlyCashFlow);

    return ClarityCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      backgroundColor: cs.surfaceContainerLow,
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.transactionsMiniAnalyticsTitle,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.transactionsMiniAnalyticsSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.52),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniMetricTile(
                  label: l10n.transactionsMiniAnalyticsSpent,
                  value: formatMoney(snapshot.spentThisMonth),
                  color: ClarityColors.financeSpending,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetricTile(
                  label: l10n.transactionsMiniAnalyticsIncome,
                  value: formatMoney(snapshot.incomeThisMonth),
                  color: ClarityColors.financePositive,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetricTile(
                  label: l10n.transactionsMiniAnalyticsNet,
                  value: formatMoney(snapshot.availableThisMonth),
                  color: snapshot.availableThisMonth >= 0
                      ? ClarityColors.financePositive
                      : ClarityColors.financeNegative,
                ),
              ),
            ],
          ),
          if (sparklineValues.length >= 2) ...[
            const SizedBox(height: 14),
            Text(
              l10n.transactionsMiniAnalyticsTrend,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.56),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _SpendSparkline(values: sparklineValues),
          ],
          if (topCategories.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              l10n.transactionsMiniAnalyticsTopCategories,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.56),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final category in topCategories)
              _MiniCategoryRow(
                name: category.name,
                amount: category.amount,
                maxAmount: topCategories.first.amount,
              ),
          ],
        ],
      ),
    );
  }
}

List<double> _sparklineSpendValues(List<MonthlyCashFlowPoint> months) {
  if (months.isEmpty) {
    return const [];
  }
  final recent = trimFinanceChartMonths(months);
  return [for (final month in recent) month.spend];
}

class _MiniMetricTile extends StatelessWidget {
  const _MiniMetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(ClarityRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.52),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCategoryRow extends StatelessWidget {
  const _MiniCategoryRow({
    required this.name,
    required this.amount,
    required this.maxAmount,
  });

  final String name;
  final double amount;
  final double maxAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fraction = maxAmount <= 0 ? 0.0 : (amount / maxAmount).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
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
                  color: cs.onSurface.withValues(alpha: 0.56),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: fraction,
              backgroundColor: cs.surfaceContainerHighest,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpendSparkline extends StatelessWidget {
  const _SpendSparkline({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];

    return SizedBox(
      height: 56,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: financeChartMaxY(values),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: ClarityColors.financeSpending,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: ClarityColors.financeSpending.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
