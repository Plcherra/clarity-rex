import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:clarity/core/formatting/formatting.dart';
import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/features/dashboard/domain/monthly_cash_flow_series.dart';
import 'package:clarity/theme/clarity_colors.dart';

import 'finance_chart_primitives.dart';
import 'finance_chart_range_switch.dart';

/// Income against spending, one pair of bars per calendar month.
class MonthlyCashFlowChart extends StatefulWidget {
  const MonthlyCashFlowChart({
    required this.months,
    this.initialRange = financeChartDefaultRange,
    this.showRangeSwitch = true,
    super.key,
  });

  /// Oldest month first.
  final List<MonthlyCashFlowPoint> months;
  final int initialRange;
  final bool showRangeSwitch;

  @override
  State<MonthlyCashFlowChart> createState() => _MonthlyCashFlowChartState();
}

class _MonthlyCashFlowChartState extends State<MonthlyCashFlowChart> {
  late int _range = widget.initialRange;

  @override
  Widget build(BuildContext context) {
    if (widget.months.isEmpty) {
      return FinanceChartEmpty(
        message: context.l10n.dashboardChartConnectAccountsCashFlow,
      );
    }

    final recent = widget.showRangeSwitch
        ? trimFinanceChartMonths(widget.months, months: _range)
        : widget.months;
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final labels = [
      for (final month in recent)
        financeChartMonthShortLabel(l10n, month.yearMonth),
    ];

    return Column(
      children: [
        if (widget.showRangeSwitch) ...[
          FinanceChartRangeSwitch(
            months: _range,
            onChanged: (range) => setState(() => _range = range),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: financeChartHeight(context),
          child: BarChart(
            BarChartData(
              maxY: financeChartMaxY([
                for (final month in recent) ...[month.income, month.spend],
              ]),
              gridData: financeChartGrid(colors),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                bottomTitles: financeChartBottomTitles(
                  labels: labels,
                  textColor: colors.textMuted,
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: financeChartBarTooltip(
                  colors: colors,
                  // fl_chart otherwise prints the raw double in a 120px box.
                  getText: (groupIndex, rodIndex) {
                    final month = recent[groupIndex];
                    final income = rodIndex == 0;
                    return '${formatYearMonthLabel(month.yearMonth)}\n'
                        '${income ? l10n.commonIncome : l10n.commonSpending} '
                        '${formatMoney(income ? month.income : month.spend)}';
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < recent.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: recent[i].income,
                        color: ClarityColors.financePositive,
                        width: 8,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      BarChartRodData(
                        toY: recent[i].spend,
                        color: ClarityColors.financeSpending,
                        width: 8,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Spending only, as a line, over the range the user picks.
class SpendTrendChart extends StatefulWidget {
  const SpendTrendChart({
    required this.months,
    this.initialRange = financeChartDefaultRange,
    this.showRangeSwitch = true,
    super.key,
  });

  /// Oldest month first.
  final List<MonthlyCashFlowPoint> months;
  final int initialRange;
  final bool showRangeSwitch;

  @override
  State<SpendTrendChart> createState() => _SpendTrendChartState();
}

class _SpendTrendChartState extends State<SpendTrendChart> {
  late int _range = widget.initialRange;

  @override
  Widget build(BuildContext context) {
    if (widget.months.isEmpty) {
      return FinanceChartEmpty(
        message: context.l10n.dashboardChartNoSpendingHistory,
      );
    }

    final recent = widget.showRangeSwitch
        ? trimFinanceChartMonths(widget.months, months: _range)
        : widget.months;
    final l10n = context.l10n;
    final colors = context.clarityColors;
    final labels = [
      for (final month in recent)
        financeChartMonthShortLabel(l10n, month.yearMonth),
    ];
    final spots = [
      for (var i = 0; i < recent.length; i++)
        FlSpot(i.toDouble(), recent[i].spend),
    ];

    return Column(
      children: [
        if (widget.showRangeSwitch) ...[
          FinanceChartRangeSwitch(
            months: _range,
            onChanged: (range) => setState(() => _range = range),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: financeChartHeight(context, compact: 180),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: spots.isEmpty ? 0 : spots.length - 1,
              minY: 0,
              maxY: financeChartMaxY([for (final month in recent) month.spend]),
              gridData: financeChartGrid(colors),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                bottomTitles: financeChartBottomTitles(
                  labels: labels,
                  textColor: colors.textMuted,
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: financeChartLineTooltip(
                  colors: colors,
                  getText: (index) {
                    final month = recent[index];
                    return '${formatYearMonthLabel(month.yearMonth)}\n'
                        '${l10n.commonSpending} ${formatMoney(month.spend)}';
                  },
                ),
              ),
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
        ),
      ],
    );
  }
}
