import '../../../core/models/models.dart';
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
    this.cashIncome = 0,
    this.cashSpend = 0,
    this.creditIncome = 0,
    this.creditSpend = 0,
  });

  /// `YYYY-MM`.
  final String yearMonth;

  /// Money that came in during the month. Positive.
  final double income;

  /// Money that went out during the month. Positive.
  final double spend;

  final double cashIncome;
  final double cashSpend;
  final double creditIncome;
  final double creditSpend;

  double get net => income - spend;

  /// Cash-account income minus cash-account spending this month.
  double get cashLeft => cashIncome - cashSpend;

  /// Card income minus card spending this month.
  double get creditLeft => creditIncome - creditSpend;
}

/// Cash flow per calendar month, oldest month first, capped to the most recent
/// [maxMonths]. Months with no counted activity are left out.
List<MonthlyCashFlowPoint> buildMonthlyCashFlowSeries(
  List<ResolvedTransaction> resolved, {
  int maxMonths = 12,
  Map<String, Account> accountsById = const {},
}) {
  final incomeByMonth = <String, double>{};
  final spendByMonth = <String, double>{};
  final cashIncomeByMonth = <String, double>{};
  final cashSpendByMonth = <String, double>{};
  final creditIncomeByMonth = <String, double>{};
  final creditSpendByMonth = <String, double>{};

  for (final row in resolved) {
    final transaction = row.transaction;
    if (transaction.pending) continue;
    final key = yearMonthKey(transaction.date);
    final credit = _isCreditAccount(accountsById, transaction.accountId);
    if (row.countsAsSpend) {
      final spend = -transaction.amount;
      spendByMonth[key] = (spendByMonth[key] ?? 0) + spend;
      if (credit) {
        creditSpendByMonth[key] = (creditSpendByMonth[key] ?? 0) + spend;
      } else {
        cashSpendByMonth[key] = (cashSpendByMonth[key] ?? 0) + spend;
      }
    } else if (row.countsAsIncome) {
      incomeByMonth[key] = (incomeByMonth[key] ?? 0) + transaction.amount;
      if (credit) {
        creditIncomeByMonth[key] =
            (creditIncomeByMonth[key] ?? 0) + transaction.amount;
      } else {
        cashIncomeByMonth[key] =
            (cashIncomeByMonth[key] ?? 0) + transaction.amount;
      }
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
        cashIncome: cashIncomeByMonth[month] ?? 0,
        cashSpend: cashSpendByMonth[month] ?? 0,
        creditIncome: creditIncomeByMonth[month] ?? 0,
        creditSpend: creditSpendByMonth[month] ?? 0,
      ),
  ];
}

bool _isCreditAccount(Map<String, Account> accountsById, String accountId) {
  return accountsById[accountId]?.type == AccountType.creditCard;
}
