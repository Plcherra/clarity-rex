import '../../../core/models/models.dart';
import 'monthly_cash_flow_series.dart';

/// Window for Income / Spending / Left on the overview period strip.
enum DashboardActivityPeriod { month, sixMonths, year }

/// Income and spending for the selected period.
///
/// This month uses the snapshot's live month totals. Longer windows sum the
/// months already on the cash-flow series so the overview card does not
/// rebuild the read model.
({double income, double spent}) dashboardActivityTotals({
  required DashboardActivityPeriod period,
  required DateTime reference,
  required double incomeThisMonth,
  required double spentThisMonth,
  required Iterable<MonthlyCashFlowPoint> monthlyCashFlow,
}) {
  if (period == DashboardActivityPeriod.month) {
    return (income: incomeThisMonth, spent: spentThisMonth);
  }
  var income = 0.0;
  var spent = 0.0;
  for (final point in monthlyCashFlow) {
    if (!dashboardActivityMonthInPeriod(
      yearMonth: point.yearMonth,
      reference: reference,
      period: period,
    )) {
      continue;
    }
    income += point.income;
    spent += point.spend;
  }
  return (income: income, spent: spent);
}

List<MonthlyCashFlowPoint> cashFlowForActivityPeriod({
  required Iterable<MonthlyCashFlowPoint> monthlyCashFlow,
  required DateTime reference,
  required DashboardActivityPeriod period,
}) {
  return [
    for (final point in monthlyCashFlow)
      if (dashboardActivityMonthInPeriod(
        yearMonth: point.yearMonth,
        reference: reference,
        period: period,
      ))
        point,
  ];
}

({double cash, double credit}) dashboardActivityLeftSplit({
  required DashboardActivityPeriod period,
  required DateTime reference,
  required Iterable<MonthlyCashFlowPoint> monthlyCashFlow,
}) {
  var cash = 0.0;
  var credit = 0.0;
  for (final point in monthlyCashFlow) {
    if (!dashboardActivityMonthInPeriod(
      yearMonth: point.yearMonth,
      reference: reference,
      period: period,
    )) {
      continue;
    }
    cash += point.cashLeft;
    credit += point.creditLeft;
  }
  return (cash: cash, credit: credit);
}

List<CategorySpend> categorySpendForActivityPeriod({
  required Map<String, Map<String, double>> monthlyCategorySpend,
  required DateTime reference,
  required DashboardActivityPeriod period,
  int limit = 5,
}) {
  final totals = <String, double>{};
  for (final entry in monthlyCategorySpend.entries) {
    if (!dashboardActivityMonthInPeriod(
      yearMonth: entry.key,
      reference: reference,
      period: period,
    )) {
      continue;
    }
    for (final category in entry.value.entries) {
      totals[category.key] = (totals[category.key] ?? 0) + category.value;
    }
  }
  final top = totals.entries
      .map((entry) => CategorySpend(name: entry.key, amount: entry.value))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  if (top.length <= limit) return top;
  return top.sublist(0, limit);
}

DateTime dashboardActivityPeriodStart(
  DateTime reference,
  DashboardActivityPeriod period,
) {
  final monthStart = DateTime(reference.year, reference.month, 1);
  return switch (period) {
    DashboardActivityPeriod.month => monthStart,
    DashboardActivityPeriod.sixMonths => _addCalendarMonths(monthStart, -5),
    DashboardActivityPeriod.year => DateTime(reference.year, 1, 1),
  };
}

bool dashboardActivityMonthInPeriod({
  required String yearMonth,
  required DateTime reference,
  required DashboardActivityPeriod period,
}) {
  final month = _parseYearMonth(yearMonth);
  if (month == null) return false;
  final start = dashboardActivityPeriodStart(reference, period);
  final end = DateTime(reference.year, reference.month, 1);
  return !month.isBefore(start) && !month.isAfter(end);
}

DateTime _addCalendarMonths(DateTime monthStart, int delta) {
  var year = monthStart.year;
  var month = monthStart.month + delta;
  while (month <= 0) {
    month += 12;
    year -= 1;
  }
  while (month > 12) {
    month -= 12;
    year += 1;
  }
  return DateTime(year, month, 1);
}

DateTime? _parseYearMonth(String yearMonth) {
  final parts = yearMonth.split('-');
  if (parts.length < 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return null;
  return DateTime(year, month, 1);
}
