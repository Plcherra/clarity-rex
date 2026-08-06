import '../../transactions/domain/spend_categories.dart';
import '../../transactions/domain/transaction_resolution.dart';

/// Sentinel category key for spend rows that still need a real category.
const String kNeedsCategoryGroupKey = '__needs_category__';

bool isNeedsCategoryGroupKey(String category) =>
    category.trim() == kNeedsCategoryGroupKey;

/// Bucket key for spend grouping — unresolved outflows share one Needs bucket.
String spendCategoryBucketKey(ResolvedTransaction transaction) {
  if (_belongsInNeedsCategoryGroup(transaction)) {
    return kNeedsCategoryGroupKey;
  }
  return transaction.displayCategory.trim();
}

class DashboardCategoryTransactionGroup {
  const DashboardCategoryTransactionGroup(this.category, this.transactions);

  final String category;
  final List<ResolvedTransaction> transactions;

  bool get isNeedsCategory => isNeedsCategoryGroupKey(category);

  int get transactionCount => transactions.length;

  double get spending => transactions
      .where(
        (transaction) =>
            !transaction.transaction.pending &&
            (transaction.countsAsSpend || isNeedsCategory),
      )
      .fold<double>(
        0,
        (sum, transaction) => sum + transaction.transaction.amount.abs(),
      );
}

bool _belongsInNeedsCategoryGroup(ResolvedTransaction transaction) {
  if (transaction.transaction.pending) return false;
  if (transaction.transaction.amount >= 0) return false;
  final label = transaction.displayCategory.trim();
  if (isIncomeCategoryLabel(label) || isIgnoredCategoryLabel(label)) {
    return false;
  }
  return transaction.needsCategorization || isUnresolvedCategoryLabel(label);
}

List<DashboardCategoryTransactionGroup>
spendingCategoryGroupsForResolvedTransactions(
  Iterable<ResolvedTransaction> transactions,
) {
  final byCategory = <String, List<ResolvedTransaction>>{};
  final needsCategory = <ResolvedTransaction>[];

  for (final transaction in transactions) {
    final bucket = spendCategoryBucketKey(transaction);
    if (isNeedsCategoryGroupKey(bucket)) {
      needsCategory.add(transaction);
      continue;
    }
    final category = bucket;
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

  if (needsCategory.isNotEmpty) {
    groups.insert(
      0,
      DashboardCategoryTransactionGroup(
        kNeedsCategoryGroupKey,
        List.unmodifiable(needsCategory),
      ),
    );
  }
  return groups;
}
