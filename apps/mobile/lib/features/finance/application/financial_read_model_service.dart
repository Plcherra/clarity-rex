import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../accounts/data/account_service.dart';
import '../../accounts/data/account_statement_import_service.dart';
import '../../budgets/data/budget_service.dart';
import '../../budgets/domain/budget_models.dart';
import '../../categories/application/category_read_model.dart';
import '../../categories/data/category_service.dart';
import '../../categories/domain/category_normalization.dart';
import '../../dashboard/domain/dashboard_snapshot.dart';
import '../../transactions/application/transaction_record_mapper.dart';
import '../../transactions/data/merchant_category_rule_service.dart';
import '../../transactions/data/transaction_service.dart';
import '../../transactions/domain/bank_statement_monthly.dart';
import '../../transactions/domain/spend_categories.dart';
import '../../transactions/domain/transaction_review.dart';
import '../../transactions/domain/transaction_resolution.dart';

final class FinancialReadModelService {
  const FinancialReadModelService({
    required AccountService accountService,
    required TransactionService transactionService,
    required BudgetService budgetService,
    required CategoryService categoryService,
    required MerchantCategoryRuleService merchantCategoryRuleService,
    required AccountStatementImportService accountStatementImportService,
    required CategoryReadModel categoryReadModel,
  }) : _accountService = accountService,
       _transactionService = transactionService,
       _budgetService = budgetService,
       _categoryService = categoryService,
       _merchantCategoryRuleService = merchantCategoryRuleService,
       _accountStatementImportService = accountStatementImportService,
       _categoryReadModel = categoryReadModel;

  final AccountService _accountService;
  final TransactionService _transactionService;
  final BudgetService _budgetService;
  final CategoryService _categoryService;
  final MerchantCategoryRuleService _merchantCategoryRuleService;
  final AccountStatementImportService _accountStatementImportService;
  final CategoryReadModel _categoryReadModel;

  Future<FinancialReadModel> load() async {
    final results = await Future.wait<Object>([
      _accountService.fetchAccounts(),
      _transactionService.fetchTransactions(),
      _budgetService.fetchBudgets(),
      _categoryService.fetchCategories(),
      _merchantCategoryRuleService.fetchRules(),
      _accountStatementImportService.fetchImports(),
    ]);
    final accounts = results[0] as List<Account>;
    final records = results[1] as List<TransactionRecord>;
    final budgets = results[2] as List<BudgetRecord>;
    final categories = results[3] as List<CategoryRecord>;
    final merchantCategoryRules = results[4] as List<MerchantCategoryRule>;
    final statementImports = results[5] as List<AccountStatementImport>;
    return FinancialReadModel.fromRecords(
      accounts: accounts,
      transactionRecords: records,
      budgets: budgets,
      categories: categories,
      merchantCategoryRules: merchantCategoryRules,
      statementImports: statementImports,
      categoryDisplayRenamesLower: _categoryReadModel.categoryDisplayRenames,
    );
  }
}

final class FinancialReadModel {
  const FinancialReadModel({
    required this.accounts,
    required this.transactionRecords,
    required this.transactions,
    required this.budgets,
    this.categories = const [],
    this.merchantCategoryRules = const [],
    this.statementImports = const [],
    this.categoryDisplayRenamesLower = const {},
  });

  factory FinancialReadModel.empty() {
    return const FinancialReadModel(
      accounts: [],
      transactionRecords: [],
      transactions: [],
      budgets: [],
      categories: [],
      merchantCategoryRules: [],
      statementImports: [],
    );
  }

  factory FinancialReadModel.fromRecords({
    required List<Account> accounts,
    required List<TransactionRecord> transactionRecords,
    required List<BudgetRecord> budgets,
    List<CategoryRecord> categories = const [],
    List<MerchantCategoryRule> merchantCategoryRules = const [],
    List<AccountStatementImport> statementImports = const [],
    Map<String, String> categoryNameById = const {},
    Map<String, String> categoryDisplayRenamesLower = const {},
  }) {
    final effectiveCategoryNameById = {
      for (final category in categories) category.id: category.name,
      ...categoryNameById,
    };
    return FinancialReadModel(
      accounts: List.unmodifiable(accounts),
      transactionRecords: List.unmodifiable(transactionRecords),
      transactions: List.unmodifiable([
        for (final record in transactionRecords)
          transactionFromRecord(
            record,
            categoryNameForId: (id) {
              final key = id?.trim();
              if (key == null || key.isEmpty) return null;
              return effectiveCategoryNameById[key];
            },
          ),
      ]),
      budgets: List.unmodifiable(budgets),
      categories: List.unmodifiable(categories),
      merchantCategoryRules: List.unmodifiable(merchantCategoryRules),
      statementImports: List.unmodifiable(statementImports),
      categoryDisplayRenamesLower: Map.unmodifiable(
        categoryDisplayRenamesLower,
      ),
    );
  }

  final List<Account> accounts;
  final List<TransactionRecord> transactionRecords;
  final List<Transaction> transactions;
  final List<BudgetRecord> budgets;
  final List<CategoryRecord> categories;
  final List<MerchantCategoryRule> merchantCategoryRules;
  final List<AccountStatementImport> statementImports;
  final Map<String, String> categoryDisplayRenamesLower;

  Map<String, Account> get accountsById => {
    for (final account in accounts) account.id: account,
  };

  Map<String, CategoryRecord> get categoriesById => {
    for (final category in categories) category.id: category,
  };

  Map<String, String> get categoryNameById => {
    for (final category in categories) category.id: category.name,
  };

  Map<String, TransactionRecord> get transactionRecordsById => {
    for (final record in transactionRecords) record.id: record,
  };

  Map<String, String> get merchantCategoryMemory {
    final categoryNames = categoryNameById;
    final out = <String, String>{};
    for (final rule in merchantCategoryRules) {
      if (rule.disabled) continue;
      final category = categoryNames[rule.categoryId]?.trim();
      if (category == null || category.isEmpty) continue;
      final key = rule.merchantKey.trim().toLowerCase();
      if (key.isNotEmpty) out[key] = category;
      for (final alias in rule.aliases) {
        final aliasKey = alias.trim().toLowerCase();
        if (aliasKey.isNotEmpty) out[aliasKey] = category;
      }
    }
    return Map.unmodifiable(out);
  }

  Map<String, AccountStatementImport> get latestStatementImportByAccount {
    final latest = <String, AccountStatementImport>{};
    for (final statementImport in statementImports) {
      final current = latest[statementImport.accountId];
      if (current == null ||
          _compareStatementImports(statementImport, current) > 0) {
        latest[statementImport.accountId] = statementImport;
      }
    }
    return Map.unmodifiable(latest);
  }

  double? dashboardBalanceForAccount(Account account) {
    final raw =
        latestStatementImportByAccount[account.id]?.statementBalance ??
        account.currentBalance;
    if (raw == null || raw.isNaN) return null;
    return switch (account.type) {
      AccountType.creditCard => raw <= 0 ? raw : -raw,
      AccountType.checking || AccountType.savings => raw,
    };
  }

  double? dashboardBalanceForScope(DashboardScope scope) {
    return switch (scope) {
      AccountDashboardScope(:final accountId) =>
        accountsById[accountId] == null
            ? null
            : dashboardBalanceForAccount(accountsById[accountId]!),
      GlobalDashboardScope() => _sumAccountBalances(),
    };
  }

  double? _sumAccountBalances() {
    var hasBalance = false;
    var total = 0.0;
    for (final account in accounts) {
      final balance = dashboardBalanceForAccount(account);
      if (balance == null) continue;
      hasBalance = true;
      total += balance;
    }
    return hasBalance ? total : null;
  }

  Map<String, List<Transaction>> get transactionsByAccount {
    final grouped = <String, List<Transaction>>{};
    for (final transaction in transactions) {
      grouped.putIfAbsent(transaction.accountId, () => <Transaction>[]);
      grouped[transaction.accountId]!.add(transaction);
    }
    return {
      for (final entry in grouped.entries)
        entry.key: List<Transaction>.unmodifiable(entry.value),
    };
  }

  List<Transaction> transactionsForScope(DashboardScope scope) {
    return switch (scope) {
      GlobalDashboardScope() => transactions,
      AccountDashboardScope(:final accountId) =>
        transactionsByAccount[accountId] ?? const <Transaction>[],
    };
  }

  DateTime dashboardReferenceForScope(
    DashboardScope scope, {
    required DateTime requested,
  }) {
    final scoped = transactionsForScope(scope);
    if (scoped.isEmpty) {
      return requested;
    }

    final hasRequestedMonth = scoped.any(
      (transaction) =>
          transaction.date.year == requested.year &&
          transaction.date.month == requested.month,
    );
    if (hasRequestedMonth) {
      return requested;
    }

    final resolved = resolvedTransactionsForScope(scope);
    DateTime? latestSpendDate;
    DateTime? latestActivityDate;
    for (final resolvedTransaction in resolved) {
      final date = resolvedTransaction.transaction.date;
      if (latestActivityDate == null || date.isAfter(latestActivityDate)) {
        latestActivityDate = date;
      }
      if (resolvedTransaction.countsAsSpend &&
          (latestSpendDate == null || date.isAfter(latestSpendDate))) {
        latestSpendDate = date;
      }
    }

    return latestSpendDate ?? latestActivityDate ?? requested;
  }

  List<AccountStatementImport> statementImportsForScope(DashboardScope scope) {
    return switch (scope) {
      GlobalDashboardScope() => statementImports,
      AccountDashboardScope(:final accountId) =>
        statementImports
            .where((statementImport) => statementImport.accountId == accountId)
            .toList(growable: false),
    };
  }

  List<ResolvedTransaction> resolvedTransactionsForScope(DashboardScope scope) {
    return resolveTransactions(
      transactionsForScope(scope),
      categoryOverrides: const {},
      categoryDisplayRenamesLower: categoryDisplayRenamesLower,
      merchantCategoryMemory: merchantCategoryMemory,
      accountsById: accountsById,
      allTransactions: transactions,
    );
  }

  List<ResolvedTransaction> internalPaymentReviewQueue(DashboardScope scope) {
    return resolvedTransactionsForScope(scope)
        .where(
          (resolved) => transactionReviewReasons(
            resolved,
          ).contains(TransactionReviewReason.internalPayment),
        )
        .toList(growable: false);
  }

  DashboardSnapshot dashboardSnapshot({
    required DashboardScope scope,
    required DateTime reference,
  }) {
    return buildDashboardSnapshot(
      scope: scope,
      reference: reference,
      accounts: accounts,
      allTransactions: transactions,
      scopedTransactions: transactionsForScope(scope),
      categoryOverrides: const {},
      categoryDisplayRenamesLower: categoryDisplayRenamesLower,
      merchantCategoryMemory: merchantCategoryMemory,
      scopedBalanceFromStatement: dashboardBalanceForScope(scope),
    );
  }

  List<BankStatementLine> refreshedLinesForMonth(MonthlyBankGroup group) {
    final byKey = <String, Transaction>{
      for (final transaction in transactions)
        transactionCategoryKey(transaction): transaction,
    };
    final lines = <BankStatementLine>[];
    for (final line in group.transactions) {
      final current = byKey[transactionCategoryKey(line.transaction)];
      if (current == null) continue;
      final resolved = resolveTransaction(
        t: current,
        categoryOverrides: const {},
        categoryDisplayRenamesLower: categoryDisplayRenamesLower,
        merchantCategoryMemory: merchantCategoryMemory,
        accountsById: accountsById,
        allTransactions: transactions,
      );
      lines.add(
        BankStatementLine(
          transaction: current,
          suggestedCategory: resolved.displayCategory,
        ),
      );
    }
    return lines;
  }

  Map<String, double> spentByDisplayCategoryForScopeInRange(
    DashboardScope scope, {
    required DateTime start,
    required DateTime end,
  }) {
    final out = <String, double>{};
    for (final resolved in resolvedTransactionsForScope(scope)) {
      final transaction = resolved.transaction;
      if (!_inRangeInclusive(transaction.date, start, end)) continue;
      if (!resolved.countsAsSpend) continue;
      final display = resolved.displayCategory;
      if (isIgnoredCategoryLabel(display) || isIncomeCategoryLabel(display)) {
        continue;
      }
      out[display] = (out[display] ?? 0) + (-transaction.amount);
    }
    return out;
  }

  Map<String, double> spentByBudgetIdentityForScopeInRange(
    DashboardScope scope, {
    required DateTime start,
    required DateTime end,
  }) {
    final out = <String, double>{};
    final recordsById = transactionRecordsById;
    for (final resolved in resolvedTransactionsForScope(scope)) {
      final transaction = resolved.transaction;
      if (!_inRangeInclusive(transaction.date, start, end)) continue;
      if (!resolved.countsAsSpend) continue;
      final recordId = transaction.fingerprint;
      final record = recordId == null ? null : recordsById[recordId];
      final identity = _budgetIdentity(
        categoryId: record?.categoryId,
        categoryKey: null,
        displayLabel: resolved.displayCategory,
      );
      if (identity.isEmpty) continue;
      out[identity] = (out[identity] ?? 0) + (-transaction.amount);
    }
    return out;
  }

  BudgetPerformanceSnapshot budgetPerformanceForScope(
    DashboardScope scope, {
    required BudgetPeriodType periodType,
    required String periodKey,
  }) {
    final start = _periodStartFor(periodType, periodKey);
    final end = _periodEndFor(periodType, periodKey);
    final period = _budgetPeriodToDatabaseValue(periodType);
    final activeBudgets = budgets
        .where((budget) {
          return budget.period == period && _sameDay(budget.startDate, start);
        })
        .toList(growable: false);
    final spentByCategory = spentByDisplayCategoryForScopeInRange(
      scope,
      start: start,
      end: end,
    );
    final spentByBudgetIdentity = spentByBudgetIdentityForScopeInRange(
      scope,
      start: start,
      end: end,
    );

    final categoryPerformance = <BudgetCategoryPerformance>[];
    for (final budget in activeBudgets) {
      final label = budget.name.trim();
      if (label.isEmpty) continue;
      final identity = _budgetIdentityForBudget(budget);
      if (identity.isEmpty) continue;
      categoryPerformance.add(
        BudgetCategoryPerformance(
          displayLabel: label,
          budgeted: budget.amount,
          spent: spentByBudgetIdentity[identity] ?? 0,
        ),
      );
    }
    categoryPerformance.sort((a, b) => b.overspent.compareTo(a.overspent));
    final topOverspending = categoryPerformance
        .where((category) => category.overspent > 0)
        .take(3)
        .toList(growable: false);

    final totalBudgeted = categoryPerformance.fold<double>(
      0,
      (sum, category) => sum + category.budgeted,
    );
    final totalSpent = spentByCategory.values.fold<double>(
      0,
      (sum, amount) => sum + amount,
    );
    final totalOverspent = categoryPerformance.fold<double>(
      0,
      (sum, category) => sum + category.overspent,
    );

    return BudgetPerformanceSnapshot(
      periodType: periodType,
      periodKey: periodKey,
      periodLabel: periodKey,
      totalBudgeted: totalBudgeted,
      totalSpent: totalSpent,
      budgetedCategoryCount: categoryPerformance.length,
      onTrackCategoryCount: categoryPerformance
          .where((category) => category.onTrack)
          .length,
      totalOverspent: totalOverspent,
      topOverspendingCategories: List.unmodifiable(topOverspending),
    );
  }
}

String _budgetIdentityForBudget(BudgetRecord budget) {
  return _budgetIdentity(
    categoryId: budget.categoryId,
    categoryKey: budget.categoryKey,
    displayLabel: budget.name,
  );
}

String _budgetIdentity({
  required String? categoryId,
  required String? categoryKey,
  required String displayLabel,
}) {
  final id = categoryId?.trim();
  if (id != null && id.isNotEmpty) return 'id:$id';
  final key = categoryKey?.trim().isNotEmpty == true
      ? categoryKey!.trim()
      : normalizedCategoryKey(displayLabel);
  if (key.isEmpty) return '';
  return 'key:$key';
}

int _compareStatementImports(
  AccountStatementImport a,
  AccountStatementImport b,
) {
  final endCompare = _nullableDateMicros(
    a.endDate,
  ).compareTo(_nullableDateMicros(b.endDate));
  if (endCompare != 0) return endCompare;
  final createdCompare = a.createdAt.microsecondsSinceEpoch.compareTo(
    b.createdAt.microsecondsSinceEpoch,
  );
  if (createdCompare != 0) return createdCompare;
  return a.importId.compareTo(b.importId);
}

int _nullableDateMicros(DateTime? value) {
  return value?.microsecondsSinceEpoch ?? -1;
}

bool _inRangeInclusive(DateTime date, DateTime start, DateTime end) {
  final value = DateTime(date.year, date.month, date.day);
  final rangeStart = DateTime(start.year, start.month, start.day);
  final rangeEnd = DateTime(end.year, end.month, end.day);
  return !value.isBefore(rangeStart) && !value.isAfter(rangeEnd);
}

DateTime _periodStartFor(BudgetPeriodType periodType, String periodKey) {
  final reference = DateTime.now();
  return switch (periodType) {
    BudgetPeriodType.monthly =>
      _parseYearMonthKey(periodKey) ??
          DateTime(reference.year, reference.month),
    BudgetPeriodType.weekly =>
      _parseDateKey(periodKey) ??
          reference.subtract(Duration(days: reference.weekday - 1)),
    BudgetPeriodType.custom =>
      _parseCustomRange(periodKey)?.start ??
          DateTime(reference.year, reference.month),
  };
}

DateTime _periodEndFor(BudgetPeriodType periodType, String periodKey) {
  final start = _periodStartFor(periodType, periodKey);
  return switch (periodType) {
    BudgetPeriodType.weekly => start.add(const Duration(days: 6)),
    BudgetPeriodType.custom => _parseCustomRange(periodKey)?.end ?? start,
    BudgetPeriodType.monthly => DateTime(start.year, start.month + 1, 0),
  };
}

String _budgetPeriodToDatabaseValue(BudgetPeriodType type) {
  return switch (type) {
    BudgetPeriodType.monthly => 'monthly',
    BudgetPeriodType.weekly => 'weekly',
    BudgetPeriodType.custom => 'custom',
  };
}

bool _sameDay(DateTime? a, DateTime b) {
  if (a == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime? _parseYearMonthKey(String? key) {
  final parts = key?.split('-') ?? const <String>[];
  if (parts.length != 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null) return null;
  return DateTime(year, month);
}

DateTime? _parseDateKey(String? key) {
  final parts = key?.split('-') ?? const <String>[];
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

({DateTime start, DateTime end})? _parseCustomRange(String? key) {
  final parts = key?.split('_') ?? const <String>[];
  if (parts.length != 2) return null;
  final start = _parseDateKey(parts[0]);
  final end = _parseDateKey(parts[1]);
  if (start == null || end == null) return null;
  return (start: start, end: end);
}
