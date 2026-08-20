import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/dashboard/domain/category_month_detail.dart';
import 'package:clarity/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:clarity/features/dashboard/domain/dashboard_transaction_groups.dart';
import 'package:clarity/features/transactions/domain/spend_categories.dart';
import 'package:clarity/features/transactions/domain/transaction_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('category month detail', () {
    test('Needs category detail matches the Overview bar for Unknown spend', () {
      final mystery = _tx(
        description: 'MYSTERY MERCHANT ZX91',
        amount: -42.5,
        day: 4,
        category: 'Unknown',
      );
      final grocery = _tx(
        description: 'PUBLIX 1234',
        amount: -20,
        day: 5,
        category: 'Grocery / Supermarket',
      );
      final transactions = [mystery, grocery];
      // Persist Unknown via override so heuristics cannot remap it to Shopping.
      final overrides = {transactionCategoryKey(mystery): 'Unknown'};

      final snapshot = buildDashboardSnapshot(
        scope: const GlobalDashboardScope(),
        reference: DateTime(2026, 7, 15),
        accounts: _accounts,
        allTransactions: transactions,
        scopedTransactions: transactions,
        categoryOverrides: overrides,
        categoryDisplayRenamesLower: const {},
        scopedBalanceFromStatement: null,
      );
      final needsBar = snapshot.topCategories.firstWhere(
        (category) => category.name == kNeedsCategoryGroupKey,
      );
      final resolved = resolveTransactions(
        transactions,
        categoryOverrides: overrides,
        categoryDisplayRenamesLower: const {},
        accountsById: {for (final account in _accounts) account.id: account},
        allTransactions: transactions,
      );
      final detail = buildCategoryMonthDetail(
        resolved: resolved,
        reference: DateTime(2026, 7, 15),
        category: kNeedsCategoryGroupKey,
      );
      final fromUnknownLabel = buildCategoryMonthDetail(
        resolved: resolved,
        reference: DateTime(2026, 7, 15),
        category: 'Unknown',
      );

      expect(detail.spent, closeTo(needsBar.amount, 0.001));
      expect(detail.transactionCount, 1);
      expect(fromUnknownLabel.spent, closeTo(needsBar.amount, 0.001));
      expect(fromUnknownLabel.transactionCount, 1);
    });

    test('the detail total is the bar the user tapped', () {
      final transactions = [
        _tx(description: 'PUBLIX 1234', amount: -80.25, day: 2),
        _tx(description: 'WINN DIXIE', amount: -40.10, day: 9),
        _tx(
          description: 'AMAZON MKTPL',
          amount: -200,
          day: 11,
          category: 'Shopping',
        ),
        _tx(
          description: 'PAYROLL DIRECT DEP',
          amount: 3000,
          day: 1,
          category: null,
        ),
      ];

      final bar = _snapshot(transactions).topCategories.firstWhere(
        (category) => category.name == 'Grocery / Supermarket',
      );
      final detail = _detail(transactions, 'Grocery / Supermarket');

      expect(detail.spent, closeTo(bar.amount, 0.001));
      expect(detail.transactionCount, 2);
      expect(
        detail.merchants.map((merchant) => merchant.merchant),
        containsAll(['Publix', 'Winn Dixie']),
      );
    });

    test('repeat visits to one shop read as one merchant', () {
      const coffeeBucket = 'Coffee / Quick Food';
      final detail = _detail([
        _tx(
          description: 'BOM DOUGH COFFEE #4471',
          amount: -6.25,
          day: 2,
          category: coffeeBucket,
        ),
        // Same shop, printed with a city and a state code.
        _tx(
          description: 'BOM DOUGH COFFEE MIAMI FL',
          amount: -5.75,
          day: 3,
          category: coffeeBucket,
        ),
        _tx(
          description: 'BOM DOUGH COFFEE #4471',
          amount: -6.25,
          day: 4,
          category: coffeeBucket,
        ),
        // Same shop again, with a neighbourhood no list would know.
        _tx(
          description: 'BOM DOUGH COFFEE BRICKELL',
          amount: -4.00,
          day: 5,
          category: coffeeBucket,
        ),
        _tx(
          description: 'WINGSTOP 338',
          amount: -24.80,
          day: 6,
          category: coffeeBucket,
        ),
      ], coffeeBucket);

      expect(detail.merchants, hasLength(2));
      final coffee = detail.merchants.singleWhere(
        (merchant) => merchant.merchant.startsWith('Bom Dough'),
      );
      expect(coffee.transactionCount, 4);
      expect(coffee.spent, closeTo(22.25, 0.001));
      // Biggest spender leads, so the mixed bucket explains itself.
      expect(detail.merchants.first.merchant, contains('Wingstop'));
    });

    test('each merchant carries the rows behind its total, newest first', () {
      const coffeeBucket = 'Coffee / Quick Food';
      final detail = _detail([
        _tx(
          description: 'BOM DOUGH COFFEE #4471',
          amount: -6.25,
          day: 2,
          category: coffeeBucket,
        ),
        _tx(
          description: 'BOM DOUGH COFFEE MIAMI FL',
          amount: -5.75,
          day: 9,
          category: coffeeBucket,
        ),
        _tx(
          description: 'WINGSTOP 338',
          amount: -24.80,
          day: 6,
          category: coffeeBucket,
        ),
      ], coffeeBucket);

      final coffee = detail.merchants.singleWhere(
        (merchant) => merchant.merchant.startsWith('Bom Dough'),
      );
      expect(coffee.transactions, hasLength(2));
      expect(
        coffee.transactions.first.transaction.description,
        'BOM DOUGH COFFEE MIAMI FL',
      );
      expect(
        detail.merchants
            .singleWhere((merchant) => merchant.merchant.contains('Wingstop'))
            .transactions
            .single
            .transaction
            .description,
        'WINGSTOP 338',
      );
    });

    test('last month is the comparison, other months are ignored', () {
      final detail = _detail([
        _tx(description: 'PUBLIX 1234', amount: -100, day: 4),
        _tx(
          description: 'PUBLIX 1234',
          amount: -50,
          day: 4,
          date: DateTime(2026, 6, 4),
        ),
        _tx(
          description: 'PUBLIX 1234',
          amount: -900,
          day: 4,
          date: DateTime(2026, 5, 4),
        ),
      ], 'Grocery / Supermarket');

      expect(detail.spent, closeTo(100, 0.001));
      expect(detail.lastMonthSpent, closeTo(50, 0.001));
      expect(detail.percentChangeFromLastMonth, closeTo(1.0, 0.001));
      expect(detail.isNewThisMonth, isFalse);
    });

    test('a category that only started this month says so', () {
      final detail = _detail([
        _tx(description: 'PUBLIX 1234', amount: -100, day: 4),
      ], 'Grocery / Supermarket');

      expect(detail.isNewThisMonth, isTrue);
      expect(detail.percentChangeFromLastMonth, isNull);
    });

    test('the share is measured against everything spent that month', () {
      final detail = _detail([
        _tx(description: 'PUBLIX 1234', amount: -250, day: 4),
        _tx(
          description: 'AMAZON MKTPL',
          amount: -750,
          day: 5,
          category: 'Shopping',
        ),
      ], 'Grocery / Supermarket');

      expect(detail.shareOfMonthSpend, closeTo(0.25, 0.001));
      expect(detail.averageTransaction, closeTo(250, 0.001));
    });

    test('card payments stay out of the detail; pending spend counts', () {
      final detail = _detail([
        _tx(description: 'PUBLIX 1234', amount: -100, day: 4),
        _tx(description: 'PUBLIX 1234 HOLD', amount: -60, day: 5, pending: true),
        _tx(
          description: 'ONLINE BANKING PAYMENT TO CRD VISA',
          amount: -900,
          day: 20,
          category: 'Credit Card Payment',
        ),
      ], 'Grocery / Supermarket');

      expect(detail.transactionCount, 2);
      expect(detail.spent, closeTo(160, 0.001));
    });
  });
}

const _accounts = [
  Account(id: 'checking', name: 'Checking', type: AccountType.checking),
  Account(id: 'visa', name: 'Visa', type: AccountType.creditCard),
];

CategoryMonthDetail _detail(List<Transaction> transactions, String category) {
  return buildCategoryMonthDetail(
    resolved: resolveTransactions(
      transactions,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: {for (final account in _accounts) account.id: account},
      allTransactions: transactions,
    ),
    reference: DateTime(2026, 7, 15),
    category: category,
  );
}

DashboardSnapshot _snapshot(List<Transaction> transactions) {
  return buildDashboardSnapshot(
    scope: const GlobalDashboardScope(),
    reference: DateTime(2026, 7, 15),
    accounts: _accounts,
    allTransactions: transactions,
    scopedTransactions: transactions,
    categoryOverrides: const {},
    categoryDisplayRenamesLower: const {},
    scopedBalanceFromStatement: null,
  );
}

Transaction _tx({
  required String description,
  required double amount,
  required int day,
  String? category = 'Grocery / Supermarket',
  bool pending = false,
  DateTime? date,
  String account = 'checking',
}) {
  return Transaction(
    date: date ?? DateTime(2026, 7, day),
    description: description,
    amount: amount,
    accountId: account,
    categoryLabel: category,
    fingerprint: '$account-$description-$amount-${date ?? day}',
    pending: pending,
  );
}
