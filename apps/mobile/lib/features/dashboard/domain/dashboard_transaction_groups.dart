import '../../transactions/domain/spend_categories.dart';
import '../../transactions/domain/transaction_resolution.dart';

class DashboardCategoryTransactionGroup {
  const DashboardCategoryTransactionGroup(this.category, this.transactions);

  final String category;
  final List<ResolvedTransaction> transactions;

  String get amountLabel => 'Spent';

  int get transactionCount => transactions.length;

  double get spending => transactions
      .where(
        (transaction) =>
            transaction.countsAsSpend && !transaction.transaction.pending,
      )
      .fold<double>(
        0,
        (sum, transaction) => sum + transaction.transaction.amount.abs(),
      );
}

List<DashboardCategoryTransactionGroup>
spendingCategoryGroupsForResolvedTransactions(
  Iterable<ResolvedTransaction> transactions,
) {
  final byCategory = <String, List<ResolvedTransaction>>{};
  for (final transaction in transactions) {
    final category = transaction.displayCategory.trim();
    if (category.isEmpty ||
        isUnresolvedCategoryLabel(category) ||
        isIncomeCategoryLabel(category) ||
        isIgnoredCategoryLabel(category) ||
        !transaction.countsAsSpend ||
        transaction.transaction.pending) {
      continue;
    }
    byCategory.putIfAbsent(category, () => []).add(transaction);
  }

  final groups = byCategory.entries
      .map((entry) => DashboardCategoryTransactionGroup(entry.key, entry.value))
      .toList();
  groups.sort((a, b) => b.spending.compareTo(a.spending));
  return groups;
}
