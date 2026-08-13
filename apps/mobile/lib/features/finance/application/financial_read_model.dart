part of 'financial_read_model_service.dart';

final class FinancialReadModelLoadIssue {
  const FinancialReadModelLoadIssue({
    required this.source,
    required this.message,
  });

  final String source;
  final String message;

  Map<String, String> toJson() => {'source': source, 'message': message};
}

final class AccountFinancialDisplay {
  const AccountFinancialDisplay({
    required this.account,
    required this.statementBalance,
    required this.availableThisMonth,
    required this.incomeThisMonth,
    required this.spentThisMonth,
    required this.netCashFlow,
  });

  final Account account;
  final double? statementBalance;
  final double availableThisMonth;
  final double incomeThisMonth;
  final double spentThisMonth;
  final double netCashFlow;
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
    this.loadIssues = const [],
  });

  factory FinancialReadModel.empty({
    List<FinancialReadModelLoadIssue> loadIssues = const [],
  }) {
    return FinancialReadModel(
      accounts: [],
      transactionRecords: [],
      transactions: [],
      budgets: [],
      categories: [],
      merchantCategoryRules: [],
      statementImports: [],
      loadIssues: loadIssues,
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
    List<FinancialReadModelLoadIssue> loadIssues = const [],
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
          if (record.removedAt == null)
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
      loadIssues: List.unmodifiable(loadIssues),
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
  final List<FinancialReadModelLoadIssue> loadIssues;

  bool get hasLoadIssues => loadIssues.isNotEmpty;

  String get dataStatus => hasLoadIssues ? 'degraded' : 'ready';

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
    return liveSignedBalanceForAccount(
      account,
      statementOverride:
          latestStatementImportByAccount[account.id]?.statementBalance,
      pendingTransactions: transactions.where(
        (transaction) =>
            transaction.accountId == account.id && transaction.pending,
      ),
    );
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

  AccountFinancialDisplay accountFinancialDisplay({
    required Account account,
    required DateTime requested,
  }) {
    final scope = AccountDashboardScope(account.id);
    final reference = dashboardReferenceForScope(scope, requested: requested);
    final snapshot = dashboardSnapshot(scope: scope, reference: reference);
    return AccountFinancialDisplay(
      account: account,
      statementBalance: dashboardBalanceForAccount(account),
      availableThisMonth: snapshot.availableThisMonth,
      incomeThisMonth: snapshot.incomeThisMonth,
      spentThisMonth: snapshot.spentThisMonth,
      netCashFlow: snapshot.incomeThisMonth - snapshot.spentThisMonth,
    );
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

  /// Month used for "this month" dashboard totals.
  ///
  /// Always the [requested] calendar month — never falls back to an older month
  /// with cash flow. Pending-only current months stay on the real month and can
  /// show $0 posted totals with a pending hint instead of silently jumping back.
  DateTime dashboardReferenceForScope(
    DashboardScope scope, {
    required DateTime requested,
  }) {
    return DateTime(requested.year, requested.month, requested.day);
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
      signedBalanceFor: dashboardBalanceForAccount,
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
      if (transaction.pending) continue;
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
      if (transaction.pending) continue;
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
          displayLabel: applyCategoryDisplayRenames(
            label,
            categoryDisplayRenamesLower,
          ),
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
      categories: List.unmodifiable(categoryPerformance),
    );
  }
}
