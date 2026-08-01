import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'package:clarity/core/layout/clarity_breakpoints.dart';
import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/theme/clarity_colors.dart';

/// Placeholder shown where a chart has nothing to draw yet.
class FinanceChartEmpty extends StatelessWidget {
  const FinanceChartEmpty({required this.message, super.key});

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

/// Short month name for a `YYYY-MM` key, e.g. `Jul`.
String financeChartMonthShortLabel(AppLocalizations l10n, String yearMonth) {
  final parts = yearMonth.split('-');
  if (parts.length != 2) {
    return yearMonth;
  }
  final month = int.tryParse(parts[1]) ?? 0;
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
    _ => yearMonth,
  };
}

AxisTitles financeChartBottomTitles({
  required List<String> labels,
  required Color textColor,
}) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      interval: 1,
      reservedSize: 22,
      getTitlesWidget: (value, _) {
        final index = value.round();
        if ((value - index).abs() > 0.001) {
          return const SizedBox.shrink();
        }
        if (index < 0 || index >= labels.length) {
          return const SizedBox.shrink();
        }
        return Text(
          labels[index],
          style: TextStyle(color: textColor, fontSize: 10),
        );
      },
    ),
  );
}

FlGridData financeChartGrid(ClarityColorTokens colors) {
  return FlGridData(
    drawVerticalLine: false,
    getDrawingHorizontalLine: (_) => FlLine(
      color: colors.divider.withValues(alpha: 0.35),
    ),
  );
}

const _tooltipTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  height: 1.35,
);

// Wide enough for "September 2026" plus a formatted amount, and pinned inside
// the chart so a bar at either edge does not open a clipped tooltip.
const _tooltipMaxWidth = 190.0;

BarTouchTooltipData financeChartBarTooltip({
  required ClarityColorTokens colors,
  required String Function(int groupIndex, int rodIndex) getText,
}) {
  return BarTouchTooltipData(
    getTooltipColor: (_) => colors.surfaceElevated,
    tooltipBorder: BorderSide(color: colors.divider),
    tooltipRoundedRadius: 10,
    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    maxContentWidth: _tooltipMaxWidth,
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
      getText(groupIndex, rodIndex),
      _tooltipTextStyle,
    ),
  );
}

LineTouchTooltipData financeChartLineTooltip({
  required ClarityColorTokens colors,
  required String Function(int index) getText,
}) {
  return LineTouchTooltipData(
    getTooltipColor: (_) => colors.surfaceElevated,
    tooltipBorder: BorderSide(color: colors.divider),
    tooltipRoundedRadius: 10,
    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    maxContentWidth: _tooltipMaxWidth,
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    getTooltipItems: (spots) => [
      for (final spot in spots)
        LineTooltipItem(getText(spot.x.round()), _tooltipTextStyle),
    ],
  );
}

@visibleForTesting
List<T> trimFinanceChartMonths<T>(List<T> items, {int months = 6}) {
  if (items.length <= months) {
    return items;
  }
  return items.sublist(items.length - months);
}

@visibleForTesting
double financeChartMaxY(Iterable<double> values) {
  final maxY = values.fold<double>(
    0,
    (max, value) => value > max ? value : max,
  );
  return maxY <= 0 ? 1 : maxY * 1.15;
}

double financeChartHeight(BuildContext context, {double compact = 200}) {
  return isClarityDesktopLayout(context) ? 300 : compact;
}
