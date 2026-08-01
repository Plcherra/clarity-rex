import '../../transactions/domain/bank_statement_monthly.dart';
import '../../transactions/domain/merchant_rollup.dart';
import '../../transactions/domain/transaction_resolution.dart';
import 'dashboard_transaction_groups.dart';

/// Everything one category did in one month: the total, how it compares, who
/// took the money, and the rows behind it.
class CategoryMonthDetail {
  const CategoryMonthDetail({
    required this.category,
    required this.spent,
    required this.lastMonthSpent,
    required this.transactionCount,
    required this.shareOfMonthSpend,
    required this.merchants,
  });

  final String category;

  /// Positive total for the reference month.
  final double spent;
  final double lastMonthSpent;
  final int transactionCount;

  /// 0..1 of everything spent that month. Zero when the month had no spending.
  final double shareOfMonthSpend;

  /// Biggest merchant first, each carrying its own rows — what tells coffee
  /// apart from fast food inside a bucket the user named once and never split.
  final List<MerchantSpendRollup> merchants;

  double get changeFromLastMonth => spent - lastMonthSpent;

  /// Growth as a fraction, or null when there is nothing to compare against.
  double? get percentChangeFromLastMonth {
    if (lastMonthSpent <= 0) return null;
    return (spent - lastMonthSpent) / lastMonthSpent;
  }

  bool get isNewThisMonth => lastMonthSpent <= 0 && spent > 0;

  double get averageTransaction =>
      transactionCount == 0 ? 0 : spent / transactionCount;
}

/// Builds the drill-down for [category] in the month of [reference].
///
/// Counts the same rows the dashboard bars count, so the detail total always
/// matches the bar the user tapped.
CategoryMonthDetail buildCategoryMonthDetail({
  required Iterable<ResolvedTransaction> resolved,
  required DateTime reference,
  required String category,
  Map<String, String> merchantNamesByTransactionKey = const {},
  String Function(ResolvedTransaction row)? merchantNameKeyOf,
}) {
  final month = yearMonthKey(reference);
  final previous = yearMonthKey(DateTime(reference.year, reference.month - 1));

  final thisMonth = <ResolvedTransaction>[];
  var monthSpend = 0.0;
  var lastMonthSpent = 0.0;

  for (final group in spendingCategoryGroupsForResolvedTransactions(resolved)) {
    for (final row in group.transactions) {
      final rowMonth = yearMonthKey(row.transaction.date);
      final amount = row.transaction.amount.abs();
      if (rowMonth == month) {
        monthSpend += amount;
        if (group.category == category) thisMonth.add(row);
      } else if (rowMonth == previous && group.category == category) {
        lastMonthSpent += amount;
      }
    }
  }

  final spent = thisMonth.fold<double>(
    0,
    (sum, row) => sum + row.transaction.amount.abs(),
  );

  return CategoryMonthDetail(
    category: category,
    spent: spent,
    lastMonthSpent: lastMonthSpent,
    transactionCount: thisMonth.length,
    shareOfMonthSpend: monthSpend <= 0 ? 0 : spent / monthSpend,
    merchants: merchantSpendRollups(
      thisMonth,
      namesByTransactionKey: merchantNamesByTransactionKey,
      keyOf: merchantNameKeyOf,
    ),
  );
}
