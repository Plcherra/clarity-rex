import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/models/account.dart';
import '../../../core/models/transaction.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../budgets/domain/budget_models.dart';
import '../../dashboard/domain/dashboard_snapshot.dart';
import '../../transactions/domain/spend_categories.dart';

final assistantFinancialContextServiceProvider =
    Provider<AssistantFinancialContextService?>((ref) => null);

final class AssistantFinancialContextService {
  const AssistantFinancialContextService(this.ui);

  final AppUiDependencies ui;

  void notifyDataChanged() {
    ui.notifyDataChanged();
  }

  Future<Map<String, dynamic>> buildSummary() async {
    const scope = GlobalDashboardScope();
    final snapshot = await _safeDashboardSnapshot(scope);
    final budgetPerformance = await _safeBudgetPerformance(scope);
    final accounts = await _safeAccounts();
    final categories = await _safeCategories();
    final budgets = await _safeBudgets();
    final transactions = await _safeTransactions();
    final resolvedTransactions = await _safeResolvedTransactions();
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
        'raw_transactions_included': true,
        'account_names_included': true,
        'merchant_names_included': true,
        'assistant_can_reference_specific_records': true,
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
        'reference_month': _monthKey(ui.budgets.spendReference),
        'transaction_count': transactions.length,
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
        for (final transaction in transactions)
          _transactionContext(
            transaction,
            accountById: accountById,
            categoryById: categoryById,
            resolvedByRecordId: resolvedByRecordId,
          ),
      ],
    };
  }

  Future<DashboardSnapshot> _safeDashboardSnapshot(DashboardScope scope) async {
    try {
      return await ui.dashboard.buildSnapshot(scope);
    } on Object {
      return const DashboardSnapshot(
        totalBalance: 0,
        spentThisMonth: 0,
        incomeThisMonth: 0,
        availableThisMonth: 0,
        topCategories: [],
        biggestLeaksThisMonth: [],
        burnRunwayDays: null,
        monthlyGroups: [],
      );
    }
  }

  Future<BudgetPerformanceSnapshot> _safeBudgetPerformance(
    DashboardScope scope,
  ) async {
    try {
      return await ui.dashboard.budgetPerformanceForScope(scope);
    } on Object {
      return BudgetPerformanceSnapshot(
        periodType: BudgetPeriodType.monthly,
        periodKey: _monthKey(ui.budgets.spendReference),
        periodLabel: _monthKey(ui.budgets.spendReference),
        totalBudgeted: 0,
        totalSpent: 0,
        budgetedCategoryCount: 0,
        onTrackCategoryCount: 0,
        totalOverspent: 0,
        topOverspendingCategories: const [],
      );
    }
  }

  Future<List<Account>> _safeAccounts() async {
    try {
      return await ui.accounts.fetchAccounts();
    } on Object {
      return const [];
    }
  }

  Future<List<CategoryRecord>> _safeCategories() async {
    try {
      return await ui.transactions.bindings.categoryService.fetchCategories();
    } on Object {
      return const [];
    }
  }

  Future<List<BudgetRecord>> _safeBudgets() async {
    try {
      return await ui.budgets.budgetService.fetchBudgets();
    } on Object {
      return const [];
    }
  }

  Future<List<TransactionRecord>> _safeTransactions() async {
    try {
      return await ui.transactions.bindings.transactionService
          .fetchTransactions();
    } on Object {
      return const [];
    }
  }

  Future<List<Transaction>> _safeResolvedTransactions() async {
    try {
      return await ui.transactions.fetchTransactions();
    } on Object {
      return const [];
    }
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
