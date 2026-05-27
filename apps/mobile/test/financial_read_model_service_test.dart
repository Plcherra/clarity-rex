import 'package:clarity/core/models/models.dart';
import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/features/accounts/data/account_statement_import_service.dart';
import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/categories/domain/category_normalization.dart';
import 'package:clarity/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:clarity/features/finance/application/financial_read_model_service.dart';
import 'package:clarity/features/transactions/data/merchant_category_rule_service.dart';
import 'package:clarity/features/transactions/domain/merchant_normalization.dart';
import 'package:clarity/features/transactions/domain/spend_categories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('budget performance uses resolved spend and reports overspending', () {
    final model = FinancialReadModel(
      accounts: const [
        Account(id: 'checking', name: 'Checking', type: AccountType.checking),
      ],
      transactionRecords: const [],
      transactions: [
        _transaction(
          description: 'TST* BOM DOUGH',
          amount: -12,
          category: 'Coffee / Quick Food',
        ),
        _transaction(
          description: 'PEARL ST MARKET',
          amount: -5,
          category: 'Grocery / Supermarket',
        ),
        _transaction(
          description: 'ZELLE PAYMENT TO FAMILY',
          amount: -100,
          category: 'Transfer Out',
        ),
      ],
      budgets: [
        _budget(name: 'Coffee / Quick Food', amount: 10),
        _budget(name: 'Grocery / Supermarket', amount: 8),
      ],
    );

    final performance = model.budgetPerformanceForScope(
      const GlobalDashboardScope(),
      periodType: BudgetPeriodType.monthly,
      periodKey: '2026-03',
    );

    expect(performance.totalBudgeted, 18);
    expect(performance.totalSpent, 17);
    expect(performance.budgetedCategoryCount, 2);
    expect(performance.onTrackCategoryCount, 1);
    expect(performance.totalOverspent, 2);
    expect(
      performance.topOverspendingCategories.single.displayLabel,
      'Coffee / Quick Food',
    );
  });

  test('budget performance matches renamed budget display by category key', () {
    final model = FinancialReadModel(
      accounts: const [
        Account(id: 'checking', name: 'Checking', type: AccountType.checking),
      ],
      transactionRecords: const [],
      transactions: [
        _transaction(
          description: 'TST* BOM DOUGH',
          amount: -12,
          category: 'Coffee / Quick Food',
        ),
      ],
      budgets: [
        _budget(
          name: 'Quick coffee',
          categoryKey: normalizedCategoryKey('Coffee / Quick Food'),
          amount: 10,
        ),
      ],
    );

    final performance = model.budgetPerformanceForScope(
      const GlobalDashboardScope(),
      periodType: BudgetPeriodType.monthly,
      periodKey: '2026-03',
    );

    expect(performance.totalSpent, 12);
    expect(performance.totalOverspent, 2);
    expect(
      performance.topOverspendingCategories.single.displayLabel,
      'Quick coffee',
    );
  });

  test('budget performance preserves budgets through category id rename', () {
    final model = FinancialReadModel.fromRecords(
      accounts: const [
        Account(id: 'checking', name: 'Checking', type: AccountType.checking),
      ],
      categories: [_category(id: 'cat-coffee', name: 'Quick Coffee')],
      transactionRecords: [
        _record(
          id: 'coffee',
          amount: 12,
          type: 'expense',
          description: 'TST* BOM DOUGH',
          categoryId: 'cat-coffee',
        ),
      ],
      budgets: [
        _budget(
          name: 'Coffee / Quick Food',
          categoryId: 'cat-coffee',
          categoryKey: normalizedCategoryKey('Coffee / Quick Food'),
          amount: 10,
        ),
      ],
    );

    final performance = model.budgetPerformanceForScope(
      const GlobalDashboardScope(),
      periodType: BudgetPeriodType.monthly,
      periodKey: '2026-03',
    );

    expect(performance.totalSpent, 12);
    expect(performance.totalOverspent, 2);
    expect(
      performance.topOverspendingCategories.single.displayLabel,
      'Coffee / Quick Food',
    );
  });

  test('budget identity spent map uses category id before display key', () {
    final model = FinancialReadModel.fromRecords(
      accounts: const [
        Account(id: 'checking', name: 'Checking', type: AccountType.checking),
      ],
      categories: [_category(id: 'cat-coffee', name: 'Quick Coffee')],
      transactionRecords: [
        _record(
          id: 'coffee',
          amount: 12,
          type: 'expense',
          description: 'TST* BOM DOUGH',
          categoryId: 'cat-coffee',
        ),
      ],
      budgets: const [],
    );

    final spent = model.spentByBudgetIdentityForScopeInRange(
      const GlobalDashboardScope(),
      start: DateTime(2026, 3),
      end: DateTime(2026, 3, 31),
    );

    expect(spent, {'id:cat-coffee': 12});
  });

  test(
    'dashboard reference falls back to latest scoped spend after restart',
    () {
      final model = FinancialReadModel(
        accounts: const [
          Account(id: 'checking', name: 'Checking', type: AccountType.checking),
        ],
        transactionRecords: const [],
        transactions: [
          _transaction(
            description: 'OLD COFFEE',
            amount: -8,
            category: 'Coffee / Quick Food',
            date: DateTime(2026, 3, 2),
          ),
          _transaction(
            description: 'LATEST SUPABASE',
            amount: -25,
            category: 'Subscriptions',
            date: DateTime(2026, 4, 22),
          ),
        ],
        budgets: const [],
      );

      final reference = model.dashboardReferenceForScope(
        const GlobalDashboardScope(),
        requested: DateTime(2026, 5, 25),
      );

      expect(reference, DateTime(2026, 4, 22));
    },
  );

  test('dashboard reference preserves requested month when it has rows', () {
    final model = FinancialReadModel(
      accounts: const [
        Account(id: 'checking', name: 'Checking', type: AccountType.checking),
      ],
      transactionRecords: const [],
      transactions: [
        _transaction(
          description: 'MAY RESTAURANT',
          amount: -42,
          category: 'Restaurants',
          date: DateTime(2026, 5, 4),
        ),
      ],
      budgets: const [],
    );

    final reference = model.dashboardReferenceForScope(
      const GlobalDashboardScope(),
      requested: DateTime(2026, 5, 25),
    );

    expect(reference, DateTime(2026, 5, 25));
  });

  test('dashboard reference skips months without counted cash flow', () {
    final model = FinancialReadModel(
      accounts: const [
        Account(id: 'checking', name: 'Checking', type: AccountType.checking),
      ],
      transactionRecords: const [],
      transactions: [
        _transaction(
          description: 'MAY REVERSAL',
          amount: 4.95,
          category: 'Ignored',
          date: DateTime(2026, 5, 4),
        ),
        _transaction(
          description: 'APRIL SUPABASE',
          amount: -25,
          category: 'Subscriptions',
          date: DateTime(2026, 4, 22),
        ),
      ],
      budgets: const [],
    );

    final reference = model.dashboardReferenceForScope(
      const GlobalDashboardScope(),
      requested: DateTime(2026, 5, 25),
    );

    expect(reference, DateTime(2026, 4, 22));
  });

  test(
    'dashboard snapshot and spent map share one resolved transaction view',
    () {
      final model = FinancialReadModel(
        accounts: const [
          Account(id: 'checking', name: 'Checking', type: AccountType.checking),
          Account(id: 'visa', name: 'Visa', type: AccountType.creditCard),
        ],
        transactionRecords: const [],
        transactions: [
          _transaction(
            description: 'ONLINE BANKING PAYMENT TO CRD VISA',
            amount: -250,
            category: 'Credit Card Payment',
          ),
          _transaction(
            accountId: 'visa',
            description: 'THANK YOU PAYMENT RECEIVED',
            amount: 250,
            category: 'Credit Card Payment',
          ),
          _transaction(
            description: 'TST* BOM DOUGH',
            amount: -12,
            category: 'Coffee / Quick Food',
          ),
        ],
        budgets: const [],
      );

      final snapshot = model.dashboardSnapshot(
        scope: const GlobalDashboardScope(),
        reference: DateTime(2026, 3, 15),
      );
      final spentByCategory = model.spentByDisplayCategoryForScopeInRange(
        const GlobalDashboardScope(),
        start: DateTime(2026, 3),
        end: DateTime(2026, 3, 31),
      );

      expect(snapshot.spentThisMonth, 12);
      expect(spentByCategory, {'Coffee / Quick Food': 12});
    },
  );

  test(
    'dashboard balances use latest statement import and normalize cards',
    () {
      final model = FinancialReadModel(
        accounts: const [
          Account(
            id: 'checking',
            name: 'Checking',
            type: AccountType.checking,
            currentBalance: 100,
          ),
          Account(
            id: 'visa',
            name: 'Visa',
            type: AccountType.creditCard,
            currentBalance: 0,
          ),
        ],
        transactionRecords: const [],
        transactions: const [],
        budgets: const [],
        statementImports: [
          _statementImport(
            accountId: 'checking',
            importId: 'old',
            balance: 1200,
            endDate: DateTime(2026, 2),
          ),
          _statementImport(
            accountId: 'checking',
            importId: 'new',
            balance: 1500,
            endDate: DateTime(2026, 3),
          ),
          _statementImport(
            accountId: 'visa',
            importId: 'card',
            balance: 250,
            endDate: DateTime(2026, 3),
          ),
        ],
      );

      expect(
        model
            .dashboardSnapshot(
              scope: const GlobalDashboardScope(),
              reference: DateTime(2026, 3),
            )
            .totalBalance,
        1250,
      );
      expect(
        model
            .dashboardSnapshot(
              scope: const AccountDashboardScope('visa'),
              reference: DateTime(2026, 3),
            )
            .totalBalance,
        -250,
      );
    },
  );

  test('account financial display separates balance from monthly net', () {
    const account = Account(
      id: 'checking',
      name: 'Checking',
      type: AccountType.checking,
      currentBalance: 0,
    );
    final model = FinancialReadModel(
      accounts: const [account],
      transactionRecords: const [],
      transactions: [
        _transaction(
          description: 'PAYROLL',
          amount: 2000,
          category: 'Income / Payroll',
        ),
        _transaction(
          description: 'GROCERY',
          amount: -750,
          category: 'Grocery / Supermarket',
        ),
      ],
      budgets: const [],
      statementImports: [
        _statementImport(
          accountId: account.id,
          importId: 'statement',
          balance: 1250,
          endDate: DateTime(2026, 3),
        ),
      ],
    );

    final display = model.accountFinancialDisplay(
      account: account,
      requested: DateTime(2026, 3, 15),
    );

    expect(display.statementBalance, 1250);
    expect(display.incomeThisMonth, 2000);
    expect(display.spentThisMonth, 750);
    expect(display.availableThisMonth, 1250);
    expect(display.netCashFlow, 1250);
  });

  test('latest statement import tie breaks by created time and import id', () {
    final model = FinancialReadModel(
      accounts: const [
        Account(id: 'checking', name: 'Checking', type: AccountType.checking),
      ],
      transactionRecords: const [],
      transactions: const [],
      budgets: const [],
      statementImports: [
        _statementImport(
          accountId: 'checking',
          importId: '100',
          balance: 1000,
          endDate: DateTime(2026, 3),
          createdAt: DateTime(2026, 3, 2),
        ),
        _statementImport(
          accountId: 'checking',
          importId: '200',
          balance: 1200,
          endDate: DateTime(2026, 3),
          createdAt: DateTime(2026, 3, 2),
        ),
        _statementImport(
          accountId: 'checking',
          importId: '150',
          balance: 1500,
          endDate: DateTime(2026, 3),
          createdAt: DateTime(2026, 3, 3),
        ),
      ],
    );

    expect(model.latestStatementImportByAccount['checking']!.importId, '150');
    expect(
      model
          .dashboardSnapshot(
            scope: const GlobalDashboardScope(),
            reference: DateTime(2026, 3),
          )
          .totalBalance,
      1500,
    );
  });

  test('statement imports are scoped for dashboard resolving state', () {
    final model = FinancialReadModel(
      accounts: const [
        Account(id: 'checking', name: 'Checking', type: AccountType.checking),
        Account(id: 'savings', name: 'Savings', type: AccountType.savings),
      ],
      transactionRecords: const [],
      transactions: const [],
      budgets: const [],
      statementImports: [
        _statementImport(
          accountId: 'checking',
          importId: 'checking-import',
          balance: 1500,
          endDate: DateTime(2026, 3),
        ),
        _statementImport(
          accountId: 'savings',
          importId: 'savings-import',
          balance: 700,
          endDate: DateTime(2026, 3),
        ),
      ],
    );

    expect(
      model
          .statementImportsForScope(const GlobalDashboardScope())
          .map((statementImport) => statementImport.importId),
      ['checking-import', 'savings-import'],
    );
    expect(
      model
          .statementImportsForScope(const AccountDashboardScope('checking'))
          .map((statementImport) => statementImport.importId),
      ['checking-import'],
    );
    expect(
      model.statementImportsForScope(const AccountDashboardScope('missing')),
      isEmpty,
    );
  });

  test('dashboard balance does not fall back to transaction sum', () {
    final model = FinancialReadModel(
      accounts: const [],
      transactionRecords: const [],
      transactions: [
        _transaction(
          description: 'OLD TRANSACTION',
          amount: -40,
          category: 'Shopping',
        ),
      ],
      budgets: const [],
    );

    expect(
      model
          .dashboardSnapshot(
            scope: const GlobalDashboardScope(),
            reference: DateTime(2026, 3),
          )
          .totalBalance,
      0,
    );
  });

  test('unconfirmed credit card payments enter review queue', () {
    final model = FinancialReadModel.fromRecords(
      accounts: const [
        Account(id: 'checking', name: 'Checking', type: AccountType.checking),
        Account(id: 'visa', name: 'Visa', type: AccountType.creditCard),
      ],
      transactionRecords: [
        _record(
          id: 'unmatched-payment',
          amount: 250,
          type: 'expense',
          description: 'ONLINE BANKING PAYMENT TO CRD VISA',
          categoryId: 'cat-cc-payment',
        ),
      ],
      budgets: const [],
      categoryNameById: const {'cat-cc-payment': 'Credit Card Payment'},
    );

    final queue = model.internalPaymentReviewQueue(
      const GlobalDashboardScope(),
    );

    expect(queue, hasLength(1));
    expect(queue.single.transaction.description, contains('VISA'));
    expect(queue.single.financialRole, FinancialRole.expense);
  });

  test(
    'persisted records resolve roles from category labels and overrides',
    () {
      final model = FinancialReadModel.fromRecords(
        accounts: const [
          Account(id: 'checking', name: 'Checking', type: AccountType.checking),
          Account(id: 'visa', name: 'Visa', type: AccountType.creditCard),
        ],
        transactionRecords: [
          _record(
            id: 'ignored',
            amount: 35,
            type: 'expense',
            description: 'BANK RETURNED ITEM FEE REVERSAL',
            categoryId: 'cat-ignored',
          ),
          _record(
            id: 'refund',
            amount: 14.99,
            type: 'income',
            description: 'MERCHANT REFUND REVERSAL',
            categoryId: 'cat-shopping',
          ),
          _record(
            id: 'transfer',
            amount: 120,
            type: 'expense',
            description: 'ZELLE PAYMENT TO FAMILY',
            categoryId: 'cat-transfer',
          ),
          _record(
            id: 'cc-out',
            amount: 250,
            type: 'expense',
            description: 'ONLINE BANKING PAYMENT TO CRD VISA',
            categoryId: 'cat-cc-payment',
          ),
          _record(
            id: 'cc-in',
            accountId: 'visa',
            amount: 250,
            type: 'income',
            description: 'THANK YOU PAYMENT RECEIVED',
            categoryId: 'cat-cc-payment',
          ),
          _record(
            id: 'payroll',
            amount: 2000,
            type: 'income',
            description: 'PAYROLL DEPOSIT',
            categoryId: 'cat-payroll',
          ),
          _record(
            id: 'manual-role',
            amount: 25,
            type: 'expense',
            description: 'TRANSFER LABEL MANUALLY MARKED EXPENSE',
            categoryId: 'cat-transfer',
            financialRole: financialRoleToStorageValue(FinancialRole.expense),
          ),
        ],
        budgets: const [],
        categoryNameById: const {
          'cat-ignored': kIgnoredCategoryLabel,
          'cat-shopping': 'Shopping',
          'cat-transfer': 'Transfer Out',
          'cat-cc-payment': 'Credit Card Payment',
          'cat-payroll': 'Income / Payroll',
        },
        categoryDisplayRenamesLower: const {},
      );

      final byDescription = {
        for (final resolved in model.resolvedTransactionsForScope(
          const GlobalDashboardScope(),
        ))
          resolved.transaction.description: resolved,
      };

      expect(
        byDescription['BANK RETURNED ITEM FEE REVERSAL']!.financialRole,
        FinancialRole.adjustment,
      );
      expect(
        byDescription['BANK RETURNED ITEM FEE REVERSAL']!.countsAsSpend,
        isFalse,
      );
      expect(
        byDescription['MERCHANT REFUND REVERSAL']!.financialRole,
        FinancialRole.refund,
      );
      expect(
        byDescription['MERCHANT REFUND REVERSAL']!.countsAsIncome,
        isFalse,
      );
      expect(
        byDescription['ZELLE PAYMENT TO FAMILY']!.financialRole,
        FinancialRole.transfer,
      );
      expect(byDescription['ZELLE PAYMENT TO FAMILY']!.countsAsSpend, isFalse);
      expect(
        byDescription['ONLINE BANKING PAYMENT TO CRD VISA']!.financialRole,
        FinancialRole.creditCardPayment,
      );
      expect(
        byDescription['ONLINE BANKING PAYMENT TO CRD VISA']!.countsAsSpend,
        isFalse,
      );
      expect(
        byDescription['PAYROLL DEPOSIT']!.financialRole,
        FinancialRole.income,
      );
      expect(byDescription['PAYROLL DEPOSIT']!.countsAsIncome, isTrue);
      expect(
        byDescription['TRANSFER LABEL MANUALLY MARKED EXPENSE']!.financialRole,
        FinancialRole.expense,
      );
      expect(
        byDescription['TRANSFER LABEL MANUALLY MARKED EXPENSE']!.countsAsSpend,
        isTrue,
      );
    },
  );

  test(
    'merchant rules are first-class read model inputs for resolved views',
    () {
      final merchantKey = merchantKeyLowerFromDescription('TST* BOM DOUGH');
      final model = FinancialReadModel.fromRecords(
        accounts: const [
          Account(id: 'checking', name: 'Checking', type: AccountType.checking),
        ],
        transactionRecords: [
          _record(
            id: 'coffee',
            amount: 12,
            type: 'expense',
            description: 'TST* BOM DOUGH',
            categoryId: null,
          ),
        ],
        budgets: [
          _budget(
            name: 'Quick coffee',
            categoryKey: normalizedCategoryKey('Coffee / Quick Food'),
            amount: 10,
          ),
        ],
        categories: [_category(id: 'cat-coffee', name: 'Coffee / Quick Food')],
        merchantCategoryRules: [
          _merchantRule(merchantKey: merchantKey, categoryId: 'cat-coffee'),
        ],
      );

      expect(model.categories.single.name, 'Coffee / Quick Food');
      expect(model.merchantCategoryMemory[merchantKey], 'Coffee / Quick Food');

      final resolved = model
          .resolvedTransactionsForScope(const GlobalDashboardScope())
          .single;
      expect(resolved.displayCategory, 'Coffee / Quick Food');
      expect(resolved.countsAsSpend, isTrue);

      final snapshot = model.dashboardSnapshot(
        scope: const GlobalDashboardScope(),
        reference: DateTime(2026, 3, 15),
      );
      expect(snapshot.topCategories.single.name, 'Coffee / Quick Food');
      expect(
        snapshot.monthlyGroups.single.transactions.single.suggestedCategory,
        'Coffee / Quick Food',
      );

      final performance = model.budgetPerformanceForScope(
        const GlobalDashboardScope(),
        periodType: BudgetPeriodType.monthly,
        periodKey: '2026-03',
      );
      expect(performance.totalSpent, 12);
      expect(performance.totalOverspent, 2);
    },
  );

  test('disabled merchant rules do not influence resolved views', () {
    final merchantKey = merchantKeyLowerFromDescription('TST* BOM DOUGH');
    final model = FinancialReadModel.fromRecords(
      accounts: const [
        Account(id: 'checking', name: 'Checking', type: AccountType.checking),
      ],
      transactionRecords: [
        _record(
          id: 'coffee',
          amount: 12,
          type: 'expense',
          description: 'TST* BOM DOUGH',
          categoryId: null,
        ),
      ],
      budgets: const [],
      categories: [_category(id: 'cat-coffee', name: 'Coffee / Quick Food')],
      merchantCategoryRules: [
        _merchantRule(
          merchantKey: merchantKey,
          categoryId: 'cat-coffee',
          disabled: true,
        ),
      ],
    );

    expect(model.merchantCategoryMemory.containsKey(merchantKey), isFalse);
  });

  test('load diagnostics mark a financial read model as degraded', () {
    const issue = FinancialReadModelLoadIssue(
      source: 'budgets',
      message: 'Could not fetch budgets.',
    );
    final model = FinancialReadModel.empty(loadIssues: const [issue]);

    expect(model.dataStatus, 'degraded');
    expect(model.hasLoadIssues, isTrue);
    expect(model.loadIssues.single.toJson(), {
      'source': 'budgets',
      'message': 'Could not fetch budgets.',
    });
  });
}

Transaction _transaction({
  String accountId = 'checking',
  required String description,
  required double amount,
  required String category,
  DateTime? date,
}) {
  return Transaction(
    date: date ?? DateTime(2026, 3, 2),
    description: description,
    amount: amount,
    accountId: accountId,
    categoryLabel: category,
  );
}

BudgetRecord _budget({
  required String name,
  required double amount,
  String? categoryId,
  String? categoryKey,
}) {
  return BudgetRecord(
    id: name,
    userId: 'user',
    name: name,
    categoryId: categoryId,
    categoryKey: categoryKey,
    amount: amount,
    period: 'monthly',
    startDate: DateTime(2026, 3),
    createdAt: DateTime(2026, 3),
    updatedAt: DateTime(2026, 3),
  );
}

TransactionRecord _record({
  required String id,
  String accountId = 'checking',
  required double amount,
  required String type,
  required String description,
  String? categoryId,
  String? financialRole,
}) {
  final now = DateTime(2026, 3);
  return TransactionRecord(
    id: id,
    userId: 'user',
    accountId: accountId,
    categoryId: categoryId,
    amount: amount,
    type: type,
    financialRole: financialRole,
    description: description,
    date: DateTime(2026, 3, 2),
    importedFromCsv: true,
    createdAt: now,
    updatedAt: now,
  );
}

CategoryRecord _category({required String id, required String name}) {
  final now = DateTime(2026, 3);
  return CategoryRecord(
    id: id,
    userId: 'user',
    name: name,
    type: 'expense',
    createdAt: now,
    updatedAt: now,
  );
}

MerchantCategoryRule _merchantRule({
  required String merchantKey,
  required String categoryId,
  bool disabled = false,
}) {
  return MerchantCategoryRule(
    id: merchantKey,
    userId: 'user',
    merchantKey: merchantKey,
    aliases: const [],
    categoryId: categoryId,
    matchType: 'normalized_exact',
    confidence: 1,
    disabled: disabled,
  );
}

AccountStatementImport _statementImport({
  required String accountId,
  required String importId,
  required double balance,
  required DateTime endDate,
  DateTime? createdAt,
}) {
  return AccountStatementImport(
    accountId: accountId,
    importId: importId,
    statementBalance: balance,
    endDate: endDate,
    transactionCount: 1,
    createdAt: createdAt ?? endDate,
  );
}
