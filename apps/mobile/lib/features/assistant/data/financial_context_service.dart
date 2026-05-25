import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/account.dart';
import '../../../core/models/transaction.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../budgets/domain/budget_models.dart';
import '../../dashboard/domain/dashboard_snapshot.dart';
import '../../finance/application/financial_read_model_service.dart';
import '../../transactions/domain/spend_categories.dart';
import '../../transactions/domain/transaction_review.dart';
import '../../transactions/domain/transaction_resolution.dart';

const int _maxRexTransactionContextRows = 120;
const int _maxRexDrilldownGroups = 18;
const int _maxRexDrilldownSampleIds = 8;

final assistantFinancialContextServiceProvider =
    Provider<AssistantFinancialContextService?>((ref) => null);

final class AssistantFinancialContextService {
  const AssistantFinancialContextService({
    required Future<FinancialReadModel> Function() loadFinancialReadModel,
    required DateTime Function() spendReference,
    required void Function() notifyDataChanged,
  }) : _loadFinancialReadModel = loadFinancialReadModel,
       _spendReference = spendReference,
       _notifyDataChanged = notifyDataChanged;

  final Future<FinancialReadModel> Function() _loadFinancialReadModel;
  final DateTime Function() _spendReference;
  final void Function() _notifyDataChanged;

  void notifyDataChanged() {
    _notifyDataChanged();
  }

  Future<Map<String, dynamic>> buildSummary() async {
    const scope = GlobalDashboardScope();
    final model = await _safeFinancialReadModel();
    final reference = model.dashboardReferenceForScope(
      scope,
      requested: _spendReference(),
    );
    final snapshot = model.dashboardSnapshot(
      scope: scope,
      reference: reference,
    );
    final budgetPerformance = model.budgetPerformanceForScope(
      scope,
      periodType: BudgetPeriodType.monthly,
      periodKey: _monthKey(reference),
    );
    final accounts = model.accounts;
    final categories = model.categories;
    final budgets = model.budgets;
    final transactions = model.transactionRecords;
    final resolvedTransactions = model.transactions;
    final resolvedViews = model.resolvedTransactionsForScope(scope);
    final selectedTransactions = _selectTransactionContextRows(
      transactions,
      resolvedViews,
    );
    final dates = transactions.map((transaction) => transaction.date).toList()
      ..sort();
    final accountById = {for (final account in accounts) account.id: account};
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final resolvedByRecordId = {
      for (final transaction in resolvedTransactions)
        if (transaction.fingerprint != null)
          transaction.fingerprint!: transaction,
    };

    return {
      'schema': 'clarity_unified_financial_context_v1',
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'integration': {
        'mode': 'unified_clarity_rex',
        'full_financial_context_included': true,
        'raw_transactions_included':
            selectedTransactions.length == transactions.length,
        'transaction_detail_mode':
            selectedTransactions.length == transactions.length
            ? 'full'
            : 'recent_and_review_rows',
        'account_names_included': true,
        'merchant_names_included': true,
        'assistant_can_reference_specific_records': true,
        'default_context_is_summary_first': true,
        'drilldown_indexes_included': true,
      },
      'retrieval': {
        'default_transaction_limit': _maxRexTransactionContextRows,
        'default_selection': selectedTransactions.length == transactions.length
            ? 'all_transactions'
            : 'review_rows_plus_recent_transactions',
        'drilldown_policy':
            'Use transaction_slices to identify the account, month, category, or review queue to inspect. Ask the user to confirm the slice when details are not included in the default transaction rows.',
        'supported_drilldown_filters': [
          'account_id',
          'account_name',
          'month',
          'category',
          'review_reason',
        ],
      },
      'available_controls': {
        'transactions': [
          'create_transaction',
          'update_transaction',
          'delete_transaction',
          'bulk_update_transaction_category',
          'delete_import_batch',
        ],
        'accounts': ['create_account', 'update_account', 'delete_account'],
        'categories': [
          'create_category',
          'update_category',
          'rename_category',
          'delete_category',
          'assign_transaction_category',
        ],
        'budgets': ['create_budget', 'update_budget', 'delete_budget'],
        'execution_policy': 'confirm_destructive_or_money_moving_changes',
      },
      'period': {
        'reference_month': _monthKey(reference),
        'transaction_count': transactions.length,
        'included_transaction_count': selectedTransactions.length,
        if (dates.isNotEmpty) 'first_transaction_date': _dateOnly(dates.first),
        if (dates.isNotEmpty) 'last_transaction_date': _dateOnly(dates.last),
      },
      'cash_flow': {
        'total_balance': _money(snapshot.totalBalance),
        'spent_this_month': _money(snapshot.spentThisMonth),
        'income_this_month': _money(snapshot.incomeThisMonth),
        'available_this_month': _money(snapshot.availableThisMonth),
        'burn_runway_days': snapshot.burnRunwayDays,
      },
      'accounts': [for (final account in accounts) _accountContext(account)],
      'categories': [
        for (final category in categories) _categoryContext(category),
      ],
      'budgets': [for (final budget in budgets) _budgetRecordContext(budget)],
      'statement_imports': [
        for (final statementImport in model.statementImports)
          {
            'account_id': statementImport.accountId,
            'import_id': statementImport.importId,
            if (statementImport.statementBalance != null)
              'statement_balance': _money(statementImport.statementBalance!),
            if (statementImport.startDate != null)
              'start_date': _dateOnly(statementImport.startDate!),
            if (statementImport.endDate != null)
              'end_date': _dateOnly(statementImport.endDate!),
            'transaction_count': statementImport.transactionCount,
          },
      ],
      'internal_payment_review_count': model
          .internalPaymentReviewQueue(scope)
          .length,
      'transaction_slices': buildRexDrilldownIndex(
        resolvedTransactions: resolvedViews,
        accountsById: accountById,
      ),
      'top_spending_categories': [
        for (final category in snapshot.topCategories.take(5))
          {'category': category.name, 'spent': _money(category.amount)},
      ],
      'biggest_month_over_month_increases': [
        for (final leak in snapshot.biggestLeaksThisMonth.take(3))
          {
            'category': leak.name,
            'spent_this_month': _money(leak.amountThisMonth),
            'spent_last_month': _money(leak.amountLastMonth),
            if (leak.percentChangeFromLastMonth != null)
              'percent_change': _percent(leak.percentChangeFromLastMonth!),
          },
      ],
      'budget': _budgetSummary(budgetPerformance),
      'transactions': [
        for (final transaction in selectedTransactions)
          _transactionContext(
            transaction,
            accountById: accountById,
            categoryById: categoryById,
            resolvedByRecordId: resolvedByRecordId,
          ),
      ],
    };
  }

  Future<FinancialReadModel> _safeFinancialReadModel() async {
    try {
      return await _loadFinancialReadModel();
    } on Object {
      return FinancialReadModel.empty();
    }
  }

  List<TransactionRecord> _selectTransactionContextRows(
    List<TransactionRecord> transactions,
    List<ResolvedTransaction> resolvedTransactions,
  ) {
    return selectRexTransactionContextRows(
      transactions: transactions,
      resolvedTransactions: resolvedTransactions,
      maxRows: _maxRexTransactionContextRows,
    );
  }

  Map<String, dynamic> _accountContext(Account account) {
    return {
      'id': account.id,
      'name': account.name,
      'type': account.type.name,
      if (account.institution != null) 'institution': account.institution,
      if (account.currentBalance != null)
        'current_balance': _money(account.currentBalance!),
    };
  }

  Map<String, dynamic> _categoryContext(CategoryRecord category) {
    return {
      'id': category.id,
      'name': category.name,
      if (category.normalizedName != null)
        'normalized_name': category.normalizedName,
      'type': category.type,
      if (category.color != null) 'color': category.color,
      if (category.icon != null) 'icon': category.icon,
    };
  }

  Map<String, dynamic> _budgetRecordContext(BudgetRecord budget) {
    return {
      'id': budget.id,
      'name': budget.name,
      if (budget.categoryId != null) 'category_id': budget.categoryId,
      if (budget.categoryKey != null) 'category_key': budget.categoryKey,
      'amount': _money(budget.amount),
      'period': budget.period,
      if (budget.startDate != null) 'start_date': _dateOnly(budget.startDate!),
      'created_at': budget.createdAt.toUtc().toIso8601String(),
      'updated_at': budget.updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _transactionContext(
    TransactionRecord transaction, {
    required Map<String, Account> accountById,
    required Map<String, CategoryRecord> categoryById,
    required Map<String, Transaction> resolvedByRecordId,
  }) {
    final account = accountById[transaction.accountId];
    final storedCategory = categoryById[transaction.categoryId];
    final resolvedTransaction = resolvedByRecordId[transaction.id];
    final resolvedCategory = resolvedTransaction == null
        ? null
        : spendGroupLabel(resolvedTransaction).trim();
    return {
      'id': transaction.id,
      'date': _dateOnly(transaction.date),
      'account_id': transaction.accountId,
      if (account != null) 'account_name': account.name,
      if (account != null) 'account_type': account.type.name,
      if (transaction.categoryId != null) 'category_id': transaction.categoryId,
      if (resolvedCategory != null && resolvedCategory.isNotEmpty)
        'category_name': resolvedCategory
      else if (storedCategory != null)
        'category_name': storedCategory.name,
      if (storedCategory != null) 'stored_category_name': storedCategory.name,
      'amount': _money(transaction.amount),
      if (resolvedTransaction != null)
        'signed_amount': _money(resolvedTransaction.amount),
      'type': transaction.type,
      if (transaction.description != null)
        'description': transaction.description,
      if (transaction.merchant != null) 'merchant': transaction.merchant,
      'imported_from_csv': transaction.importedFromCsv,
      if (transaction.importId != null) 'import_id': transaction.importId,
      'created_at': transaction.createdAt.toUtc().toIso8601String(),
      'updated_at': transaction.updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _budgetSummary(BudgetPerformanceSnapshot budget) {
    return {
      'period_type': budget.periodType.name,
      'period_key': budget.periodKey,
      'total_budgeted': _money(budget.totalBudgeted),
      'total_spent': _money(budget.totalSpent),
      'total_remaining': _money(budget.totalBudgeted - budget.totalSpent),
      'total_overspent': _money(budget.totalOverspent),
      'budgeted_category_count': budget.budgetedCategoryCount,
      'on_track_category_count': budget.onTrackCategoryCount,
      'top_overspending_categories': [
        for (final category in budget.topOverspendingCategories.take(3))
          {
            'category': category.displayLabel,
            'budgeted': _money(category.budgeted),
            'spent': _money(category.spent),
            'overspent': _money(category.overspent),
          },
      ],
    };
  }

  double _money(double value) => (value * 100).roundToDouble() / 100;

  double _percent(double value) => (value * 10).roundToDouble() / 10;

  String _monthKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}';
  }

  String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

List<TransactionRecord> selectRexTransactionContextRows({
  required List<TransactionRecord> transactions,
  required List<ResolvedTransaction> resolvedTransactions,
  int maxRows = _maxRexTransactionContextRows,
}) {
  if (transactions.length <= maxRows) {
    return transactions;
  }
  final reviewIds = <String>{};
  for (final resolved in resolvedTransactions) {
    final id = resolved.transaction.fingerprint;
    if (id == null || id.isEmpty) continue;
    if (transactionReviewReasons(resolved).isNotEmpty) {
      reviewIds.add(id);
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
            label: account?.name ?? transaction.accountId,
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
    for (final group in sorted.take(_maxRexDrilldownGroups)) group.toContext(),
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
        for (final sample in _samples.take(_maxRexDrilldownSampleIds))
          _transactionId(sample),
      ],
    };
  }
}

String _transactionId(ResolvedTransaction resolved) {
  return resolved.transaction.fingerprint ??
      transactionCategoryKey(resolved.transaction);
}

String _reviewReasonLabel(TransactionReviewReason reason) {
  return switch (reason) {
    TransactionReviewReason.needsCategory => 'Needs category',
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
