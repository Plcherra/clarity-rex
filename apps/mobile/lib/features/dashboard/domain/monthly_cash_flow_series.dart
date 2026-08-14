import '../../transactions/domain/bank_statement_monthly.dart';
import '../../transactions/domain/transaction_resolution.dart';

/// Income and spending for one calendar month.
///
/// Measured with the same rules the overview card uses — settled rows only,
/// counted through [ResolvedTransaction.countsAsIncome] and
/// [ResolvedTransaction.countsAsSpend], so transfers between the user's own
/// accounts and credit-card payments never land on both sides of the month.
class MonthlyCashFlowPoint {
  const MonthlyCashFlowPoint({
    required this.yearMonth,
    required this.income,
    required this.spend,
  });

  /// `YYYY-MM`.
  final String yearMonth;

  /// Money that came in during the month. Positive.
  final double income;

  /// Money that went out during the month. Positive.
  final double spend;

  double get net => income - spend;
}

/// Cash flow per calendar month, oldest month first, capped to the most recent
/// [maxMonths]. Months with no counted activity are left out.
List<MonthlyCashFlowPoint> buildMonthlyCashFlowSeries(
  List<ResolvedTransaction> resolved, {
  int maxMonths = 12,
}) {
  final incomeByMonth = <String, double>{};
  final spendByMonth = <String, double>{};

  for (final row in resolved) {
    final transaction = row.transaction;
    if (transaction.pending) continue;
    final key = yearMonthKey(transaction.date);
    if (row.countsAsSpend) {
      spendByMonth[key] = (spendByMonth[key] ?? 0) + -transaction.amount;
    } else if (row.countsAsIncome) {
      incomeByMonth[key] = (incomeByMonth[key] ?? 0) + transaction.amount;
    }
  }

  final months = <String>{...incomeByMonth.keys, ...spendByMonth.keys}.toList()
    ..sort();
  final visible = months.length <= maxMonths
      ? months
      : months.sublist(months.length - maxMonths);

  return [
    for (final month in visible)
      MonthlyCashFlowPoint(
        yearMonth: month,
        income: incomeByMonth[month] ?? 0,
        spend: spendByMonth[month] ?? 0,
      ),
  ];
}
