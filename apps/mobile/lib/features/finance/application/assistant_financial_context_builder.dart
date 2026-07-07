import 'package:clarity/core/models/account.dart';
import 'package:clarity/core/models/transaction.dart';
import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:clarity/features/finance/application/financial_read_model_service.dart';
import 'package:clarity/features/transactions/domain/spend_categories.dart';
import 'package:clarity/rex/data/rex_financial_context_query.dart';
import 'package:clarity/rex/data/rex_financial_transaction_policy.dart';

final class AssistantFinancialContextBuilder {
  const AssistantFinancialContextBuilder({
    required this.loadFinancialReadModel,
    required this.spendReference,
    this.localeTag,
  });

  final Future<FinancialReadModel> Function() loadFinancialReadModel;
  final DateTime Function() spendReference;
  final String Function()? localeTag;

  static Map<String, dynamic> unavailableSummary({
    required String source,
    required String message,
  }) {
    final issue = {'source': source, 'message': message};
    return {
      'schema': 'clarity_unified_financial_context_v1',
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'data_status': {
        'state': 'unavailable',
        'financial_context_complete': false,
        'load_errors': [issue],
      },
      'load_errors': [issue],
      'integration': {
        'mode': 'unified_clarity_rex',
        'full_financial_context_included': false,
        'raw_transactions_included': false,
        'transaction_detail_mode': 'unavailable',
        'account_names_included': false,
        'merchant_names_included': false,
        'assistant_can_reference_specific_records': false,
        'default_context_is_summary_first': true,
        'drilldown_indexes_included': false,
      },
      'retrieval': {
        'default_transaction_limit': 0,
        'default_selection': 'none',
        'drilldown_policy':
            'Financial context is unavailable. Do not infer accounts, budgets, balances, transactions, or categories.',
        'supported_drilldown_filters': const <String>[],
      },
      'available_controls': availableControls(),
      'period': {'transaction_count': 0, 'included_transaction_count': 0},
      'cash_flow': const <String, dynamic>{},
      'financial_data_sources': {
        'primary_source': 'unavailable',
        'plaid_accounts': 0,
        'manual_csv_accounts': 0,
        'plaid_transactions': 0,
        'csv_transactions': 0,
        'manual_transactions': 0,
        'pending_plaid_transactions': 0,
      },
      'accounts': const <Map<String, dynamic>>[],
      'categories': const <Map<String, dynamic>>[],
      'budgets': const <Map<String, dynamic>>[],
      'transactions': const <Map<String, dynamic>>[],
    };
  }

  Future<Map<String, dynamic>> buildSummary({String? userMessage}) async {
    const scope = GlobalDashboardScope();
    final model = await _safeFinancialReadModel();
    final reference = model.dashboardReferenceForScope(
      scope,
      requested: spendReference(),
    );
    final referenceMonth = monthKey(reference);
    final snapshot = model.dashboardSnapshot(
      scope: scope,
      reference: reference,
    );
    final budgetPerformance = model.budgetPerformanceForScope(
      scope,
      periodType: BudgetPeriodType.monthly,
      periodKey: referenceMonth,
    );
    final accounts = model.accounts;
    final categories = model.categories;
    final budgets = model.budgets;
    final transactions = model.transactionRecords
        .where((transaction) => transaction.removedAt == null)
        .toList(growable: false);
    final resolvedTransactions = model.transactions;
    final resolvedViews = model.resolvedTransactionsForScope(scope);
    final query = extractRexFinancialContextQuery(
      userMessage ?? '',
      budgets: budgets,
      categories: categories,
    );
    final matchedTransactions = selectRexMatchedTransactionRows(
      transactions: transactions,
      resolvedTransactions: resolvedViews,
      query: query,
    );
    final selectedTransactions = selectRexTransactionContextRows(
      transactions: transactions,
      resolvedTransactions: resolvedViews,
      query: query.hasFilters ? query : null,
      maxRows: kMaxRexTransactionContextRows,
    );
    final categorySpendThisMonth = buildCategorySpendThisMonth(
      resolvedTransactions: resolvedViews,
      referenceMonth: referenceMonth,
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
      'locale': localeTag?.call(),
      'data_status': {
        'state': model.dataStatus,
        'financial_context_complete': !model.hasLoadIssues,
        'load_errors': [for (final issue in model.loadIssues) issue.toJson()],
      },
      'load_errors': [for (final issue in model.loadIssues) issue.toJson()],
      'freshness': freshnessContext(accounts),
      'integration': {
        'mode': 'unified_clarity_rex',
        'full_financial_context_included': !model.hasLoadIssues,
        'raw_transactions_included':
            selectedTransactions.length == transactions.length,
        'transaction_detail_mode':
            selectedTransactions.length == transactions.length
            ? 'full'
            : query.hasFilters
            ? 'matched_rows_plus_recent_transactions'
            : 'recent_and_review_rows',
        'account_names_included': true,
        'merchant_names_included': true,
        'assistant_can_reference_specific_records': true,
        'default_context_is_summary_first': !query.hasFilters,
        'drilldown_indexes_included': true,
        'matched_transaction_selection_enabled': query.hasFilters,
      },
      'retrieval': {
        'default_transaction_limit': kMaxRexTransactionContextRows,
        'default_selection': selectedTransactions.length == transactions.length
            ? 'all_transactions'
            : query.hasFilters
            ? 'matched_rows_plus_recent_transactions'
            : 'review_rows_plus_recent_transactions',
        if (query.hasFilters) 'matched_query': query.toContextJson(),
        if (query.hasFilters) 'matched_transaction_count': matchedTransactions.length,
        'drilldown_policy':
            'Use included transactions, matched_transactions, and category_spend_this_month first. If a requested slice has sample_transactions, list those names/descriptions. If details are not included, say Clarity only sent an aggregate summary for this turn; do not claim you can pull/check/fetch more details unless an execution result provides them.',
        'supported_drilldown_filters': [
          'account_id',
          'account_name',
          'month',
          'category',
          'merchant',
          'budget_name',
          'review_reason',
        ],
      },
      'available_controls': availableControls(),
      'period': {
        'reference_month': referenceMonth,
        'transaction_count': transactions.length,
        'included_transaction_count': selectedTransactions.length,
        if (query.hasFilters)
          'included_matched_transaction_count': matchedTransactions
              .where(
                (transaction) => selectedTransactions.any(
                  (selected) => selected.id == transaction.id,
                ),
              )
              .length,
        if (dates.isNotEmpty) 'first_transaction_date': dateOnly(dates.first),
        if (dates.isNotEmpty) 'last_transaction_date': dateOnly(dates.last),
      },
      'cash_flow': {
        'total_balance': money(snapshot.totalBalance),
        'spent_this_month': money(snapshot.spentThisMonth),
        'income_this_month': money(snapshot.incomeThisMonth),
        'available_this_month': money(snapshot.availableThisMonth),
        'burn_runway_days': snapshot.burnRunwayDays,
      },
      'financial_data_sources': financialDataSources(
        accounts: accounts,
        transactions: transactions,
      ),
      'accounts': [for (final account in accounts) accountContext(account)],
      'categories': [
        for (final category in categories) categoryContext(category),
      ],
      'budgets': [for (final budget in budgets) budgetRecordContext(budget)],
      'statement_imports': [
        for (final statementImport in model.statementImports)
          {
            'account_id': statementImport.accountId,
            'import_id': statementImport.importId,
            if (statementImport.statementBalance != null)
              'statement_balance': money(statementImport.statementBalance!),
            if (statementImport.startDate != null)
              'start_date': dateOnly(statementImport.startDate!),
            if (statementImport.endDate != null)
              'end_date': dateOnly(statementImport.endDate!),
            'transaction_count': statementImport.transactionCount,
          },
      ],
      'transaction_slices': buildRexDrilldownIndex(
        resolvedTransactions: resolvedViews,
        accountsById: accountById,
      ),
      'top_spending_categories': [
        for (final category in snapshot.topCategories.take(5))
          {'category': category.name, 'spent': money(category.amount)},
      ],
      'biggest_month_over_month_increases': [
        for (final leak in snapshot.biggestLeaksThisMonth.take(3))
          {
            'category': leak.name,
            'spent_this_month': money(leak.amountThisMonth),
            'spent_last_month': money(leak.amountLastMonth),
            if (leak.percentChangeFromLastMonth != null)
              'percent_change': percent(leak.percentChangeFromLastMonth!),
          },
      ],
      'budget': budgetSummary(budgetPerformance),
      if (categorySpendThisMonth.isNotEmpty)
        'category_spend_this_month': categorySpendThisMonth,
      if (query.hasFilters && matchedTransactions.isNotEmpty)
        'matched_transactions': [
          for (final transaction in matchedTransactions)
            transactionContext(
              transaction,
              accountById: accountById,
              categoryById: categoryById,
              resolvedByRecordId: resolvedByRecordId,
            ),
        ],
      'transactions': [
        for (final transaction in selectedTransactions)
          transactionContext(
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
      return await loadFinancialReadModel();
    } on Object catch (error) {
      return FinancialReadModel.empty(
        loadIssues: [
          FinancialReadModelLoadIssue(
            source: 'financial_read_model',
            message: error.toString(),
          ),
        ],
      );
    }
  }

  static Map<String, dynamic> accountContext(Account account) {
    final institution = account.plaidInstitutionName ?? account.institution;
    return {
      'id': account.id,
      'name': account.displayName,
      'display_name': account.displayName,
      if (account.displaySubtitle.isNotEmpty)
        'display_detail': account.displaySubtitle,
      'type': account.type.name,
      'source':
          account.source ?? (account.isPlaidConnected ? 'plaid' : 'manual'),
      'source_label': account.sourceLabel,
      'plaid_connected': account.isPlaidConnected,
      'institution': ?institution,
      if (account.plaidAccountMask != null) 'mask': account.plaidAccountMask,
      if (account.syncStatus != null) 'sync_status': account.syncStatus,
      if (account.lastSyncedAt != null)
        'last_synced_at': account.lastSyncedAt!.toUtc().toIso8601String(),
      if (account.currentBalance != null)
        'current_balance': money(account.currentBalance!),
      if (account.plaidAvailableBalance != null)
        'available_balance': money(account.plaidAvailableBalance!),
    };
  }

  static Map<String, dynamic> categoryContext(CategoryRecord category) {
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

  static Map<String, dynamic> budgetRecordContext(BudgetRecord budget) {
    return {
      'id': budget.id,
      'name': budget.name,
      if (budget.categoryId != null) 'category_id': budget.categoryId,
      if (budget.categoryKey != null) 'category_key': budget.categoryKey,
      'amount': money(budget.amount),
      'period': budget.period,
      if (budget.startDate != null) 'start_date': dateOnly(budget.startDate!),
      'created_at': budget.createdAt.toUtc().toIso8601String(),
      'updated_at': budget.updatedAt.toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> transactionContext(
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
      'date': dateOnly(transaction.date),
      'account_id': transaction.accountId,
      if (account != null) 'account_name': account.displayName,
      if (account != null && account.displaySubtitle.isNotEmpty)
        'account_detail': account.displaySubtitle,
      if (account != null) 'account_type': account.type.name,
      if (transaction.categoryId != null) 'category_id': transaction.categoryId,
      if (resolvedCategory != null && resolvedCategory.isNotEmpty)
        'category_name': resolvedCategory
      else if (storedCategory != null)
        'category_name': storedCategory.name,
      if (storedCategory != null) 'stored_category_name': storedCategory.name,
      'amount': money(transaction.amount),
      if (resolvedTransaction != null)
        'signed_amount': money(resolvedTransaction.amount),
      'type': transaction.type,
      'source': transaction.source,
      'source_label': transaction.source == 'plaid' ? 'Plaid' : 'Manual/CSV',
      'pending': transaction.pending,
      if (transaction.description != null)
        'description': transaction.description,
      if (transaction.merchant != null) 'merchant': transaction.merchant,
      'imported_from_csv': transaction.importedFromCsv,
      if (transaction.importId != null) 'import_id': transaction.importId,
      'created_at': transaction.createdAt.toUtc().toIso8601String(),
      'updated_at': transaction.updatedAt.toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> budgetSummary(BudgetPerformanceSnapshot budget) {
    return {
      'period_type': budget.periodType.name,
      'period_key': budget.periodKey,
      'total_budgeted': money(budget.totalBudgeted),
      'total_spent': money(budget.totalSpent),
      'total_remaining': money(budget.totalBudgeted - budget.totalSpent),
      'total_overspent': money(budget.totalOverspent),
      'budgeted_category_count': budget.budgetedCategoryCount,
      'on_track_category_count': budget.onTrackCategoryCount,
      'top_overspending_categories': [
        for (final category in budget.topOverspendingCategories.take(3))
          {
            'category': category.displayLabel,
            'budgeted': money(category.budgeted),
            'spent': money(category.spent),
            'overspent': money(category.overspent),
          },
      ],
      'categories': [
        for (final category in budget.categories)
          {
            'category': category.displayLabel,
            'budgeted': money(category.budgeted),
            'spent': money(category.spent),
            'remaining': money(category.remaining),
            'overspent': money(category.overspent),
            'on_track': category.onTrack,
          },
      ],
    };
  }

  static Map<String, dynamic> financialDataSources({
    required List<Account> accounts,
    required List<TransactionRecord> transactions,
  }) {
    final plaidAccounts = accounts
        .where((account) => account.isPlaidConnected)
        .length;
    final csvAccounts = accounts.length - plaidAccounts;
    final plaidTransactions = transactions
        .where((transaction) => transaction.source == 'plaid')
        .length;
    final csvTransactions = transactions
        .where((transaction) => transaction.source == 'csv')
        .length;
    final manualTransactions = transactions
        .where((transaction) => transaction.source == 'manual')
        .length;
    final pendingPlaidTransactions = transactions
        .where(
          (transaction) => transaction.source == 'plaid' && transaction.pending,
        )
        .length;
    return {
      'plaid_accounts': plaidAccounts,
      'manual_csv_accounts': csvAccounts,
      'plaid_transactions': plaidTransactions,
      'csv_transactions': csvTransactions,
      'manual_transactions': manualTransactions,
      'pending_plaid_transactions': pendingPlaidTransactions,
      'primary_source': plaidAccounts > 0 ? 'plaid' : 'manual_csv',
    };
  }

  static Map<String, dynamic> availableControls() {
    return {
      'transactions': [
        'create_transaction',
        'update_transaction',
        'delete_transaction',
        'bulk_update_transaction_category',
        'delete_import_batch',
      ],
      'accounts': ['create_account', 'update_account', 'delete_account'],
      'categories': ['create_category', 'update_category', 'delete_category'],
      'budgets': ['create_budget', 'update_budget', 'delete_budget'],
      'execution_policy': 'confirm_destructive_or_money_moving_changes',
      'notes': [
        'Assign a transaction category with update_transaction.category_id.',
        'Rename a category with update_category.name.',
      ],
    };
  }

  static Map<String, dynamic> freshnessContext(List<Account> accounts) {
    final now = DateTime.now().toUtc();
    final staleAccounts = <Map<String, dynamic>>[];
    final unknownAccounts = <Map<String, dynamic>>[];
    DateTime? newestSync;
    for (final account in accounts.where(
      (account) => account.isPlaidConnected,
    )) {
      final syncedAt = account.lastSyncedAt?.toUtc();
      if (syncedAt == null) {
        unknownAccounts.add({
          'account_id': account.id,
          'account_name': account.displayName,
          'reason': 'missing_last_sync',
        });
        continue;
      }
      if (newestSync == null || syncedAt.isAfter(newestSync)) {
        newestSync = syncedAt;
      }
      final age = now.difference(syncedAt);
      if (age.inHours >= 24) {
        staleAccounts.add({
          'account_id': account.id,
          'account_name': account.displayName,
          'last_synced_at': syncedAt.toIso8601String(),
          'age_hours': age.inHours,
        });
      }
    }
    return {
      'state': staleAccounts.isNotEmpty
          ? 'stale'
          : unknownAccounts.isNotEmpty
          ? 'unknown'
          : 'fresh',
      if (newestSync != null) 'newest_sync_at': newestSync.toIso8601String(),
      'stale_plaid_accounts': staleAccounts,
      'unknown_sync_accounts': unknownAccounts,
      if (staleAccounts.isNotEmpty)
        'guidance':
            'Financial sync is stale. Quote exact current_balance values from account rows only; do not estimate payoff amounts, interest, or fees that may have changed since last sync.',
    };
  }

  static double money(double value) => (value * 100).roundToDouble() / 100;

  static double percent(double value) => (value * 10).roundToDouble() / 10;

  static String monthKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}';
  }

  static String dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
