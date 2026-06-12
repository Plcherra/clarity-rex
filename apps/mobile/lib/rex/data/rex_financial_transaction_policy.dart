import 'package:clarity/core/models/account.dart';
import 'package:clarity/core/models/transaction.dart';
import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/features/transactions/domain/spend_categories.dart';
import 'package:clarity/features/transactions/domain/transaction_review.dart';
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
  final reviewIds = <String>{};
  for (final resolved in resolvedTransactions) {
    if (transactionReviewReasons(resolved).isNotEmpty) {
      final id = _recordIdForResolvedTransaction(resolved, transactions);
      if (id != null && id.isNotEmpty) reviewIds.add(id);
    }
  }
  final newest = [...transactions]
    ..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.id.compareTo(a.id);
    });
  final selectedIds = <String>{};
  for (final record in newest) {
    if (selectedIds.length >= maxRows) break;
    if (reviewIds.contains(record.id)) selectedIds.add(record.id);
  }
  for (final record in newest) {
    if (selectedIds.length >= maxRows) break;
    selectedIds.add(record.id);
  }
  return [
    for (final record in newest)
      if (selectedIds.contains(record.id)) record,
  ];
}

Map<String, dynamic> buildRexDrilldownIndex({
  required List<ResolvedTransaction> resolvedTransactions,
  required Map<String, Account> accountsById,
}) {
  final byMonth = <String, _RexSliceAccumulator>{};
  final byAccount = <String, _RexSliceAccumulator>{};
  final byCategory = <String, _RexSliceAccumulator>{};
  final byReview = <String, _RexSliceAccumulator>{};

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

    final category = resolved.displayCategory.trim().isEmpty
        ? 'Unknown'
        : resolved.displayCategory.trim();
    byCategory
        .putIfAbsent(
          category,
          () => _RexSliceAccumulator(key: category, label: category),
        )
        .add(resolved);

    for (final reason in transactionReviewReasons(resolved)) {
      final key = reason.name;
      byReview
          .putIfAbsent(
            key,
            () => _RexSliceAccumulator(
              key: key,
              label: _reviewReasonLabel(reason),
            ),
          )
          .add(resolved);
    }
  }

  return {
    'months': _sliceContexts(byMonth.values, sortByLatest: true),
    'accounts': _sliceContexts(byAccount.values),
    'categories': _sliceContexts(byCategory.values, sortBySpend: true),
    'review_queues': _sliceContexts(byReview.values),
  };
}

List<Map<String, dynamic>> _sliceContexts(
  Iterable<_RexSliceAccumulator> groups, {
  bool sortByLatest = false,
  bool sortBySpend = false,
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
    for (final group in sorted.take(kMaxRexDrilldownGroups)) group.toContext(),
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

  Map<String, dynamic> toContext() {
    _samples.sort((a, b) {
      final byDate = b.transaction.date.compareTo(a.transaction.date);
      if (byDate != 0) return byDate;
      return _transactionId(b).compareTo(_transactionId(a));
    });
    return {
      'key': key,
      'label': label,
      'transaction_count': transactionCount,
      'spend': _moneyValue(spend),
      'income': _moneyValue(income),
      'net': _moneyValue(net),
      if (latestDate != null) 'latest_date': _dateOnlyValue(latestDate!),
      'sample_transaction_ids': [
        for (final sample in _samples.take(kMaxRexDrilldownSampleIds))
          _transactionId(sample),
      ],
      'sample_transactions': [
        for (final sample in _samples.take(kMaxRexDrilldownSampleIds))
          _sampleTransactionContext(sample),
      ],
    };
  }
}

String? _recordIdForResolvedTransaction(
  ResolvedTransaction resolved,
  List<TransactionRecord> records,
) {
  final fingerprint = resolved.transaction.fingerprint;
  if (fingerprint != null &&
      fingerprint.isNotEmpty &&
      records.any((record) => record.id == fingerprint)) {
    return fingerprint;
  }

  final key = transactionCategoryKey(resolved.transaction);
  for (final record in records) {
    if (_recordIdentityKey(record) == key) {
      return record.id;
    }
  }
  return fingerprint;
}

String _recordIdentityKey(TransactionRecord record) {
  return transactionCategoryKey(
    Transaction(
      date: record.date,
      description: record.description ?? record.merchant ?? '',
      amount: record.type == 'expense' ? -record.amount.abs() : record.amount,
      accountId: record.accountId,
      categoryLabel: record.categoryId,
      fingerprint: record.id,
      source: record.source,
      pending: record.pending,
    ),
  );
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

String _reviewReasonLabel(TransactionReviewReason reason) {
  return switch (reason) {
    TransactionReviewReason.needsCategory => 'Uncategorized review',
    TransactionReviewReason.internalPayment => 'Possible internal payment',
    TransactionReviewReason.manualRole => 'Manual role',
    TransactionReviewReason.ignored => 'Ignored',
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
