/// Record-to-context mappers for the assistant financial pack.
///
/// Pure shaping only: each function turns one Clarity record into the JSON the
/// backend reads. Selection, capping, and assembly stay in the builder.
library;

import 'package:clarity/core/models/account.dart';
import 'package:clarity/core/models/transaction.dart';
import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/transactions/domain/spend_categories.dart';

Map<String, dynamic> accountContext(Account account) {
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

Map<String, dynamic> categoryContext(CategoryRecord category) {
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

Map<String, dynamic> budgetRecordContext(BudgetRecord budget) {
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

Map<String, dynamic> transactionContext(
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

Map<String, dynamic> budgetSummary(BudgetPerformanceSnapshot budget) {
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

Map<String, dynamic> financialDataSources({
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

Map<String, dynamic> availableControls() {
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

Map<String, dynamic> freshnessContext(List<Account> accounts) {
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

double money(double value) => (value * 100).roundToDouble() / 100;

double percent(double value) => (value * 10).roundToDouble() / 10;

String monthKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}';
}

String dateOnly(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
