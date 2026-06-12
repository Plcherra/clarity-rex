import 'package:clarity/core/models/models.dart';
import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/features/accounts/data/account_statement_import_service.dart';
import 'package:clarity/rex/data/financial_context_service.dart';
import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/categories/domain/category_normalization.dart';
import 'package:clarity/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:clarity/features/finance/application/financial_read_model_service.dart';
import 'package:clarity/features/transactions/domain/transaction_review.dart';
import 'package:clarity/features/transactions/domain/transaction_fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'CSV-style records feed dashboard budgets and Rex from one resolved model',
    () {
      final model = FinancialReadModel.fromRecords(
        accounts: _accounts,
        categories: _categories,
        transactionRecords: [
          _record(
            id: 'payroll',
            amount: 3000,
            type: 'income',
            description: 'PAYROLL DEPOSIT',
            categoryId: 'cat-payroll',
          ),
          _record(
            id: 'coffee',
            amount: 12,
            type: 'expense',
            description: 'TST* BOM DOUGH MOBILE PURCHASE',
            categoryId: 'cat-coffee',
          ),
          _record(
            id: 'grocery',
            amount: 85,
            type: 'expense',
            description: 'PEARL ST MARKET',
            categoryId: 'cat-grocery',
          ),
          _record(
            id: 'cc-out',
            amount: 250,
            type: 'expense',
            description: 'ONLINE BANKING PAYMENT TO CRD VISA',
            categoryId: 'cat-card-payment',
          ),
          _record(
            id: 'cc-in',
            accountId: 'visa',
            amount: 250,
            type: 'income',
            description: 'THANK YOU PAYMENT RECEIVED',
            categoryId: 'cat-card-payment',
          ),
          _record(
            id: 'transfer',
            amount: 400,
            type: 'expense',
            description: 'TRANSFER TO SAVINGS',
            categoryId: 'cat-transfer',
          ),
          _record(
            id: 'refund',
            amount: 20,
            type: 'income',
            description: 'MERCHANT REFUND REVERSAL',
            categoryId: 'cat-shopping',
          ),
          _record(
            id: 'pharmacy',
            accountId: 'visa',
            amount: 33.41,
            type: 'expense',
            description: 'CVS/PHARMACY #123',
            categoryId: 'cat-pharmacy',
          ),
          _record(
            id: 'unknown',
            amount: 7,
            type: 'expense',
            description: 'UNCLASSIFIED MERCHANT',
            categoryId: 'cat-unknown',
          ),
        ],
        budgets: [
          _budget(
            id: 'budget-coffee',
            name: 'Coffee budget',
            categoryId: 'cat-coffee',
            amount: 15,
          ),
          _budget(
            id: 'budget-grocery',
            name: 'Grocery budget',
            categoryId: 'cat-grocery',
            amount: 90,
          ),
        ],
        statementImports: [
          _statementImport(
            accountId: 'checking',
            importId: 'checking-mar',
            balance: 2400,
          ),
          _statementImport(
            accountId: 'savings',
            importId: 'savings-mar',
            balance: 5000,
          ),
          _statementImport(
            accountId: 'visa',
            importId: 'visa-mar',
            balance: 300,
          ),
        ],
      );

      final snapshot = model.dashboardSnapshot(
        scope: const GlobalDashboardScope(),
        reference: DateTime(2026, 3, 20),
      );
      expect(snapshot.totalBalance, 7100);
      expect(snapshot.incomeThisMonth, 3000);
      expect(snapshot.spentThisMonth, 137.41);
      expect(snapshot.availableThisMonth, 2862.59);
      expect(_topCategoryAmount(snapshot, 'Grocery / Supermarket'), 85);
      expect(_topCategoryAmount(snapshot, 'Pharmacy / Health'), 33.41);
      expect(
        snapshot.topCategories.map((category) => category.name),
        isNot(contains('Credit Card Payment')),
      );
      expect(
        snapshot.topCategories.map((category) => category.name),
        isNot(contains('Transfer Out')),
      );

      final budget = model.budgetPerformanceForScope(
        const GlobalDashboardScope(),
        periodType: BudgetPeriodType.monthly,
        periodKey: '2026-03',
      );
      expect(budget.totalBudgeted, 105);
      expect(budget.totalSpent, 137.41);
      expect(budget.totalOverspent, 0);
      expect(budget.onTrackCategoryCount, 2);

      final resolved = model.resolvedTransactionsForScope(
        const GlobalDashboardScope(),
      );
      final reviewRows = resolved
          .where(
            (transaction) => transactionReviewReasons(
              transaction,
            ).contains(TransactionReviewReason.needsCategory),
          )
          .toList(growable: false);
      expect(reviewRows.map((row) => row.transaction.fingerprint), ['unknown']);

      final rexIndex = buildRexDrilldownIndex(
        resolvedTransactions: resolved,
        accountsById: model.accountsById,
      );
      final reviewQueues =
          rexIndex['review_queues'] as List<Map<String, dynamic>>;
      final needsCategory = reviewQueues.singleWhere(
        (queue) => queue['key'] == 'needsCategory',
      );
      expect(needsCategory['label'], 'Uncategorized review');
      expect(needsCategory['transaction_count'], 1);
      expect(needsCategory['sample_transaction_ids'], contains('unknown'));
      final samples = needsCategory['sample_transactions'] as List<dynamic>;
      expect(
        (samples.single as Map<String, dynamic>)['description'],
        'UNCLASSIFIED MERCHANT',
      );

      final categories = rexIndex['categories'] as List<Map<String, dynamic>>;
      final grocery = categories.singleWhere(
        (category) => category['label'] == 'Grocery / Supermarket',
      );
      expect(grocery['spend'], 85);
    },
  );

  test(
    'statement balances are authoritative for checking savings and card scopes',
    () {
      final model = FinancialReadModel.fromRecords(
        accounts: _accounts,
        transactionRecords: [
          _record(
            id: 'old-spend',
            amount: 999,
            type: 'expense',
            description: 'OLD SPEND SHOULD NOT BECOME BALANCE',
            categoryId: 'cat-grocery',
          ),
        ],
        budgets: const [],
        categories: _categories,
        statementImports: [
          _statementImport(
            accountId: 'checking',
            importId: 'checking-old',
            balance: 1000,
            endDate: DateTime(2026, 2, 28),
          ),
          _statementImport(
            accountId: 'checking',
            importId: 'checking-new',
            balance: 2400,
            endDate: DateTime(2026, 3, 31),
          ),
          _statementImport(
            accountId: 'savings',
            importId: 'savings-new',
            balance: 5000,
            endDate: DateTime(2026, 3, 31),
          ),
          _statementImport(
            accountId: 'visa',
            importId: 'visa-new',
            balance: 300,
            endDate: DateTime(2026, 3, 31),
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
        7100,
      );
      expect(
        model
            .dashboardSnapshot(
              scope: const AccountDashboardScope('checking'),
              reference: DateTime(2026, 3),
            )
            .totalBalance,
        2400,
      );
      expect(
        model
            .dashboardSnapshot(
              scope: const AccountDashboardScope('savings'),
              reference: DateTime(2026, 3),
            )
            .totalBalance,
        5000,
      );
      expect(
        model
            .dashboardSnapshot(
              scope: const AccountDashboardScope('visa'),
              reference: DateTime(2026, 3),
            )
            .totalBalance,
        -300,
      );
      expect(
        model.latestStatementImportByAccount['checking']!.importId,
        'checking-new',
      );
    },
  );

  test(
    'Rex default transaction selection keeps review rows in large ledgers',
    () {
      final records = [
        _record(
          id: 'old-unknown',
          amount: 9,
          type: 'expense',
          description: 'OLD UNKNOWN MERCHANT',
          categoryId: 'cat-unknown',
          date: DateTime(2025, 1, 2),
        ),
        for (var i = 0; i < 160; i += 1)
          _record(
            id: 'recent-$i',
            amount: 2,
            type: 'expense',
            description: 'RECENT COFFEE $i',
            categoryId: 'cat-coffee',
            date: DateTime(2026, 1, 1).add(Duration(days: i)),
          ),
      ];
      final model = FinancialReadModel.fromRecords(
        accounts: _accounts,
        categories: _categories,
        transactionRecords: records,
        budgets: const [],
      );

      final selected = selectRexTransactionContextRows(
        transactions: model.transactionRecords,
        resolvedTransactions: model.resolvedTransactionsForScope(
          const GlobalDashboardScope(),
        ),
        maxRows: 120,
      );

      expect(selected, hasLength(120));
      expect(selected.map((record) => record.id), contains('old-unknown'));
      expect(selected.first.id, 'recent-159');
    },
  );

  test(
    'Plaid-style and CSV-style imports share the same dedupe fingerprint',
    () {
      final csvTransaction = Transaction(
        accountId: 'checking',
        date: DateTime(2026, 3, 18),
        amount: -42.17,
        description: ' SQ *Coffee   Shop ',
      );
      final plaidTransaction = Transaction(
        accountId: 'checking',
        date: DateTime(2026, 3, 18),
        amount: -42.17,
        description: 'sq *coffee shop',
      );
      final otherAccountTransaction = Transaction(
        accountId: 'visa',
        date: DateTime(2026, 3, 18),
        amount: -42.17,
        description: 'sq *coffee shop',
      );

      expect(
        transactionFingerprint(plaidTransaction),
        transactionFingerprint(csvTransaction),
      );
      expect(
        transactionFingerprint(otherAccountTransaction),
        isNot(transactionFingerprint(csvTransaction)),
      );
    },
  );
}

const _accounts = [
  Account(id: 'checking', name: 'Checking', type: AccountType.checking),
  Account(id: 'savings', name: 'Savings', type: AccountType.savings),
  Account(id: 'visa', name: 'Visa', type: AccountType.creditCard),
];

final _categories = [
  _category(id: 'cat-payroll', name: 'Income / Payroll', type: 'income'),
  _category(id: 'cat-coffee', name: 'Coffee / Quick Food'),
  _category(id: 'cat-grocery', name: 'Grocery / Supermarket'),
  _category(id: 'cat-card-payment', name: 'Credit Card Payment'),
  _category(id: 'cat-transfer', name: 'Transfer Out'),
  _category(id: 'cat-shopping', name: 'Shopping'),
  _category(id: 'cat-pharmacy', name: 'Pharmacy / Health'),
  _category(id: 'cat-unknown', name: kUnknownCategoryName),
];

double _topCategoryAmount(DashboardSnapshot snapshot, String name) {
  return snapshot.topCategories
      .singleWhere((category) => category.name == name)
      .amount;
}

BudgetRecord _budget({
  required String id,
  required String name,
  required String categoryId,
  required double amount,
}) {
  return BudgetRecord(
    id: id,
    userId: 'user',
    name: name,
    categoryId: categoryId,
    categoryKey: null,
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
  required String categoryId,
  DateTime? date,
}) {
  final now = DateTime(2026, 3);
  return TransactionRecord(
    id: id,
    userId: 'user',
    accountId: accountId,
    categoryId: categoryId,
    amount: amount,
    type: type,
    description: description,
    date: date ?? DateTime(2026, 3, 15),
    merchant: description,
    importedFromCsv: true,
    importId: 'import-mar',
    createdAt: now,
    updatedAt: now,
  );
}

CategoryRecord _category({
  required String id,
  required String name,
  String type = 'expense',
}) {
  final now = DateTime(2026, 3);
  return CategoryRecord(
    id: id,
    userId: 'user',
    name: name,
    normalizedName: normalizedCategoryKey(name),
    type: type,
    createdAt: now,
    updatedAt: now,
  );
}

AccountStatementImport _statementImport({
  required String accountId,
  required String importId,
  required double balance,
  DateTime? endDate,
}) {
  return AccountStatementImport(
    accountId: accountId,
    importId: importId,
    statementBalance: balance,
    startDate: DateTime(2026, 3, 1),
    endDate: endDate ?? DateTime(2026, 3, 31),
    transactionCount: 1,
    createdAt: endDate ?? DateTime(2026, 3, 31),
  );
}
