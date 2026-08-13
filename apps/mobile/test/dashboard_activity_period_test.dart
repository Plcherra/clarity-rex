import 'package:clarity/features/dashboard/domain/dashboard_activity_period.dart';
import 'package:clarity/features/dashboard/domain/monthly_cash_flow_series.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final august = DateTime(2026, 8, 13);

  test('six months includes the selected month and five prior months', () {
    expect(
      dashboardActivityPeriodStart(august, DashboardActivityPeriod.sixMonths),
      DateTime(2026, 3, 1),
    );
    expect(
      dashboardActivityMonthInPeriod(
        yearMonth: '2026-03',
        reference: august,
        period: DashboardActivityPeriod.sixMonths,
      ),
      isTrue,
    );
    expect(
      dashboardActivityMonthInPeriod(
        yearMonth: '2026-02',
        reference: august,
        period: DashboardActivityPeriod.sixMonths,
      ),
      isFalse,
    );
    expect(
      dashboardActivityMonthInPeriod(
        yearMonth: '2026-08',
        reference: august,
        period: DashboardActivityPeriod.sixMonths,
      ),
      isTrue,
    );
  });

  test('year includes January through the selected month', () {
    expect(
      dashboardActivityPeriodStart(august, DashboardActivityPeriod.year),
      DateTime(2026, 1, 1),
    );
    expect(
      dashboardActivityMonthInPeriod(
        yearMonth: '2025-12',
        reference: august,
        period: DashboardActivityPeriod.year,
      ),
      isFalse,
    );
    expect(
      dashboardActivityMonthInPeriod(
        yearMonth: '2026-01',
        reference: august,
        period: DashboardActivityPeriod.year,
      ),
      isTrue,
    );
  });

  test('longer windows sum cash-flow months and skip empty gaps', () {
    const points = [
      MonthlyCashFlowPoint(yearMonth: '2026-01', income: 2000, spend: 1500),
      MonthlyCashFlowPoint(yearMonth: '2026-03', income: 1800, spend: 900),
      MonthlyCashFlowPoint(yearMonth: '2026-08', income: 1471.24, spend: 509.10),
    ];

    final month = dashboardActivityTotals(
      period: DashboardActivityPeriod.month,
      reference: august,
      incomeThisMonth: 1471.24,
      spentThisMonth: 509.10,
      monthlyCashFlow: points,
    );
    expect(month.income, closeTo(1471.24, 0.001));
    expect(month.spent, closeTo(509.10, 0.001));

    final sixMonths = dashboardActivityTotals(
      period: DashboardActivityPeriod.sixMonths,
      reference: august,
      incomeThisMonth: 1471.24,
      spentThisMonth: 509.10,
      monthlyCashFlow: points,
    );
    expect(sixMonths.income, closeTo(3271.24, 0.001));
    expect(sixMonths.spent, closeTo(1409.10, 0.001));

    final year = dashboardActivityTotals(
      period: DashboardActivityPeriod.year,
      reference: august,
      incomeThisMonth: 1471.24,
      spentThisMonth: 509.10,
      monthlyCashFlow: points,
    );
    expect(year.income, closeTo(5271.24, 0.001));
    expect(year.spent, closeTo(2909.10, 0.001));
  });

  test('chart months follow the overview period, including sparse history', () {
    const points = [
      MonthlyCashFlowPoint(yearMonth: '2026-03', income: 1800, spend: 900),
      MonthlyCashFlowPoint(yearMonth: '2026-08', income: 1471.24, spend: 509.10),
    ];

    expect(
      cashFlowForActivityPeriod(
        monthlyCashFlow: points,
        reference: august,
        period: DashboardActivityPeriod.month,
      ).map((point) => point.yearMonth),
      ['2026-08'],
    );
    expect(
      cashFlowForActivityPeriod(
        monthlyCashFlow: points,
        reference: august,
        period: DashboardActivityPeriod.sixMonths,
      ).map((point) => point.yearMonth),
      ['2026-03', '2026-08'],
    );
    expect(
      cashFlowForActivityPeriod(
        monthlyCashFlow: points,
        reference: august,
        period: DashboardActivityPeriod.year,
      ).map((point) => point.yearMonth),
      ['2026-03', '2026-08'],
    );
  });

  test('category spend sums every month in the selected period', () {
    const monthly = {
      '2026-03': {'Fitness': 40.0, 'Coffee / Quick Food': 10.0},
      '2026-08': {'Fitness': 159.0, 'Transportation': 63.42},
    };

    final month = categorySpendForActivityPeriod(
      monthlyCategorySpend: monthly,
      reference: august,
      period: DashboardActivityPeriod.month,
    );
    expect(month.first.name, 'Fitness');
    expect(month.first.amount, 159);
    expect(month, hasLength(2));

    final sixMonths = categorySpendForActivityPeriod(
      monthlyCategorySpend: monthly,
      reference: august,
      period: DashboardActivityPeriod.sixMonths,
    );
    expect(sixMonths.first.name, 'Fitness');
    expect(sixMonths.first.amount, 199);
  });

  test('period leftover splits cash vs card flow', () {
    const points = [
      MonthlyCashFlowPoint(
        yearMonth: '2026-08',
        income: 1471.24,
        spend: 509.10,
        cashIncome: 1471.24,
        cashSpend: 238.42,
        creditSpend: 270.68,
      ),
    ];

    final split = dashboardActivityLeftSplit(
      period: DashboardActivityPeriod.month,
      reference: august,
      monthlyCashFlow: points,
    );
    expect(split.cash, closeTo(1232.82, 0.001));
    expect(split.credit, closeTo(-270.68, 0.001));
    expect(split.cash + split.credit, closeTo(962.14, 0.001));
  });
}
