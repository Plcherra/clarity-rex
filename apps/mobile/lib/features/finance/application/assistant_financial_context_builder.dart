import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:clarity/features/finance/application/assistant_financial_context_records.dart';
import 'package:clarity/features/finance/application/financial_read_model_service.dart';
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
      merchantNamesByTransactionId: {
        for (final transaction in transactions)
          if ((transaction.merchant ?? '').trim().isNotEmpty)
            transaction.id: transaction.merchant!.trim(),
      },
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
}
