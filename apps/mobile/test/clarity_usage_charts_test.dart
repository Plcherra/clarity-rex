import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_usage_charts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  group('usage chart helpers', () {
    test('usageChartMaxY adds headroom and handles zero values', () {
      expect(usageChartMaxY(const [0, 0]), 1);
      expect(usageChartMaxY(const [50]), closeTo(60, 0.001));
    });
  });

  group('usage chart widgets', () {
    testWidgets('VoiceUsageDailyLineChart shows empty state', (tester) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          const VoiceUsageDailyLineChart(values: [], labels: []),
        ),
      );

      expect(find.text('No daily voice usage yet.'), findsOneWidget);
    });

    testWidgets('UsageDailyBarChart scales maxY from daily values', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          const UsageDailyBarChart(
            values: [2, 4, 10],
            labels: ['Mon', 'Tue', 'Wed'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.maxY, closeTo(12, 0.001));
    });

    testWidgets('UsageRadarChart shows empty state for mismatched data', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          const UsageRadarChart(
            titles: ['Voice'],
            values: [],
          ),
        ),
      );

      expect(
        find.text('Not enough usage data for radar chart.'),
        findsOneWidget,
      );
    });

    testWidgets('empty usage charts use theme muted text color', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          const UsageDailyBarChart(values: [], labels: []),
        ),
      );

      final text = tester.widget<Text>(find.text('No daily call data yet.'));
      expect(text.style?.color, ClarityColors.dark.textMuted);
    });
  });
}

Widget wrapWithClarityTheme(Widget child) {
  return wrapWithL10n(
    Theme(
      data: ThemeData.dark().copyWith(
        extensions: const [ClarityColors.dark],
      ),
      child: Scaffold(body: child),
    ),
  );
}
