import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/theme/clarity_colors.dart';

import '../core/l10n/app_l10n.dart';

/// Usage chart granularity (owner admin + profile usage):
/// - [VoiceUsageDailyLineChart] and [UsageDailyBarChart]: one point/bar per day
///   in the loaded daily series (voice seconds or LLM call counts).
/// - [UsageRadarChart]: month-to-date totals across usage dimensions, not daily.
class VoiceUsageDailyLineChart extends StatelessWidget {
  const VoiceUsageDailyLineChart({
    required this.values,
    required this.labels,
    super.key,
  });

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return _ChartEmpty(message: context.l10n.usageChartNoDailyVoiceUsage);
    }

    final colors = context.clarityColors;
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final spots = [
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), values[i] / 60),
    ];

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY <= 0 ? 1 : (maxY / 60) * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: colors.divider.withValues(alpha: 0.35),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, _) => Text(
                  value.round().toString(),
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: _labelInterval(values.length),
                getTitlesWidget: (value, _) {
                  final index = value.round();
                  if (index < 0 || index >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
              color: colors.accent,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: colors.accent.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UsageRadarChart extends StatelessWidget {
  const UsageRadarChart({
    required this.titles,
    required this.values,
    super.key,
  });

  final List<String> titles;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty || titles.length != values.length) {
      return _ChartEmpty(
        message: context.l10n.usageChartNotEnoughRadarData,
      );
    }

    final colors = context.clarityColors;

    return SizedBox(
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
          titlePositionPercentageOffset: 0.12,
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
            RadarDataSet(
              fillColor: colors.accent.withValues(alpha: 0.22),
              borderColor: colors.accent,
              borderWidth: 2,
              entryRadius: 2,
              dataEntries: [
                for (final value in values)
                  RadarEntry(value: value <= 0 ? 0 : value),
              ],
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}

class UsageDailyBarChart extends StatelessWidget {
  const UsageDailyBarChart({
    required this.values,
    required this.labels,
    super.key,
  });

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return _ChartEmpty(message: context.l10n.usageChartNoDailyCallData);
    }

    final colors = context.clarityColors;

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: usageChartMaxY(values),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: colors.divider.withValues(alpha: 0.35),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, _) => Text(
                  value.round().toString(),
                  style: TextStyle(color: colors.textMuted, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: _labelInterval(values.length),
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
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    color: colors.accent,
                    width: 10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.clarityColors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

double _labelInterval(int count) {
  if (count <= 5) {
    return 1;
  }
  if (count <= 12) {
    return 2;
  }
  return (count / 6).ceilToDouble();
}

String shortDayLabel(AppLocalizations l10n, DateTime date) {
  return switch (date.weekday) {
    DateTime.monday => l10n.usageChartDayMon,
    DateTime.tuesday => l10n.usageChartDayTue,
    DateTime.wednesday => l10n.usageChartDayWed,
    DateTime.thursday => l10n.usageChartDayThu,
    DateTime.friday => l10n.usageChartDayFri,
    DateTime.saturday => l10n.usageChartDaySat,
    DateTime.sunday => l10n.usageChartDaySun,
    _ => l10n.usageChartDayMon,
  };
}

@visibleForTesting
double usageChartMaxY(Iterable<double> values) {
  final maxY = values.fold<double>(
    0,
    (max, value) => value > max ? value : max,
  );
  return maxY <= 0 ? 1 : maxY * 1.2;
}
