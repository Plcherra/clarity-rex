import 'package:clarity/core/models/account.dart';
import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/features/transactions/domain/spend_categories.dart';
import 'package:clarity/features/transactions/domain/transaction_resolution.dart';

const int kMaxRexTransactionContextRows = 120;
const int kMaxRexDrilldownGroups = 18;
const int kMaxRexDrilldownSampleIds = 8;

List<TransactionRecord> selectRexTransactionContextRows({
  required List<TransactionRecord> transactions,
  required List<ResolvedTransaction> resolvedTransactions,
  int maxRows = kMaxRexTransactionContextRows,
}) {
  if (transactions.length <= maxRows) {
    return transactions;
  }
  final newest = [...transactions]
    ..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.id.compareTo(a.id);
    });
  return newest.take(maxRows).toList(growable: false);
}

Map<String, dynamic> buildRexDrilldownIndex({
  required List<ResolvedTransaction> resolvedTransactions,
  required Map<String, Account> accountsById,
}) {
  final byMonth = <String, _RexSliceAccumulator>{};
  final byAccount = <String, _RexSliceAccumulator>{};
  final byCategory = <String, _RexSliceAccumulator>{};

  for (final resolved in resolvedTransactions) {
    final transaction = resolved.transaction;
    final month = _monthKeyForDate(transaction.date);
    byMonth
        .putIfAbsent(
          month,
          () => _RexSliceAccumulator(key: month, label: month),
        )
        .add(resolved);

    final account = accountsById[transaction.accountId];
    byAccount
        .putIfAbsent(
          transaction.accountId,
          () => _RexSliceAccumulator(
            key: transaction.accountId,
            label: account?.displayName ?? transaction.accountId,
          ),
        )
        .add(resolved);

    if (_isVisibleFinancialCategorySlice(resolved)) {
      final category = resolved.displayCategory.trim();
      byCategory
          .putIfAbsent(
            category,
            () => _RexSliceAccumulator(key: category, label: category),
          )
          .add(resolved);
    }
  }

  return {
    'months': _sliceContexts(byMonth.values, sortByLatest: true),
    'accounts': _sliceContexts(byAccount.values),
    'categories': _sliceContexts(byCategory.values, sortBySpend: true),
  };
}

List<Map<String, dynamic>> _sliceContexts(
  Iterable<_RexSliceAccumulator> groups, {
  bool sortByLatest = false,
  bool sortBySpend = false,
  int sampleLimit = kMaxRexDrilldownSampleIds,
  bool userFacingCategory = true,
}) {
  final sorted = groups.toList();
  sorted.sort((a, b) {
    if (sortByLatest) {
      final byDate = (b.latestDate ?? DateTime(0)).compareTo(
        a.latestDate ?? DateTime(0),
      );
      if (byDate != 0) return byDate;
    }
    if (sortBySpend) {
      final bySpend = b.spend.compareTo(a.spend);
      if (bySpend != 0) return bySpend;
    }
    return b.transactionCount.compareTo(a.transactionCount);
  });
  return [
    for (final group in sorted.take(kMaxRexDrilldownGroups))
      group.toContext(
        sampleLimit: sampleLimit,
        userFacingCategory: userFacingCategory,
      ),
  ];
}

class _RexSliceAccumulator {
  _RexSliceAccumulator({required this.key, required this.label});

  final String key;
  final String label;
  int transactionCount = 0;
  double spend = 0;
  double income = 0;
  double net = 0;
  DateTime? latestDate;
  final _samples = <ResolvedTransaction>[];

  void add(ResolvedTransaction resolved) {
    final transaction = resolved.transaction;
    transactionCount += 1;
    net += transaction.amount;
    if (resolved.countsAsSpend) spend += transaction.amount.abs();
    if (resolved.countsAsIncome) income += transaction.amount;
    if (latestDate == null || transaction.date.isAfter(latestDate!)) {
      latestDate = transaction.date;
    }
    _samples.add(resolved);
  }

  Map<String, dynamic> toContext({
    required int sampleLimit,
    required bool userFacingCategory,
  }) {
    _samples.sort((a, b) {
      final byDate = b.transaction.date.compareTo(a.transaction.date);
      if (byDate != 0) return byDate;
      return _transactionId(b).compareTo(_transactionId(a));
    });
    final includedSamples = _samples.take(sampleLimit).toList(growable: false);
    final allRowsIncluded = includedSamples.length == transactionCount;
    return {
      'key': key,
      'label': label,
      'user_facing_category': userFacingCategory,
      'transaction_count': transactionCount,
      'spend': _moneyValue(spend),
      'income': _moneyValue(income),
      'net': _moneyValue(net),
      if (latestDate != null) 'latest_date': _dateOnlyValue(latestDate!),
      'included_sample_count': includedSamples.length,
      'detail_status': allRowsIncluded
          ? 'all_rows_included'
          : 'sample_rows_included',
      'can_list_all_included_rows': allRowsIncluded,
      'sample_transaction_ids': [
        for (final sample in includedSamples) _transactionId(sample),
      ],
      'sample_transactions': [
        for (final sample in includedSamples) _sampleTransactionContext(sample),
      ],
    };
  }
}

bool _isVisibleFinancialCategorySlice(ResolvedTransaction resolved) {
  final transaction = resolved.transaction;
  final category = resolved.displayCategory.trim();
  return category.isNotEmpty &&
      !isUnresolvedCategoryLabel(category) &&
      !isIncomeCategoryLabel(category) &&
      !isIgnoredCategoryLabel(category) &&
      resolved.countsAsSpend &&
      !transaction.pending;
}

String _transactionId(ResolvedTransaction resolved) {
  return resolved.transaction.fingerprint ??
      transactionCategoryKey(resolved.transaction);
}

Map<String, dynamic> _sampleTransactionContext(ResolvedTransaction resolved) {
  final transaction = resolved.transaction;
  return {
    'id': _transactionId(resolved),
    'date': _dateOnlyValue(transaction.date),
    'description': transaction.description,
    'amount': _moneyValue(transaction.amount),
    'account_id': transaction.accountId,
    'category': resolved.displayCategory,
    'source': transaction.source,
    'pending': transaction.pending,
  };
}

double _moneyValue(double value) => (value * 100).roundToDouble() / 100;

String _monthKeyForDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}';
}

String _dateOnlyValue(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
