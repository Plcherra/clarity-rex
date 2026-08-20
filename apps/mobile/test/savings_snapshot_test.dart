import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('savings on the dashboard', () {
    test('there is no savings line without a savings account', () {
      final snapshot = _snapshot(
        accounts: const [
          Account(id: 'checking', name: 'Checking', type: AccountType.checking),
        ],
        transactions: [_tx(amount: -40, account: 'checking', day: 3)],
      );

      expect(snapshot.savings, isNull);
    });

    test('the month change is what actually moved into savings', () {
      final snapshot = _snapshot(
        accounts: _accounts,
        transactions: [
          _tx(amount: 400, account: 'savings', day: 9),
          _tx(amount: -100, account: 'savings', day: 21),
          // Last month stays out. Pending this month counts until it posts.
          _tx(amount: 900, account: 'savings', day: 4, month: 6),
          _tx(amount: 500, account: 'savings', day: 28, pending: true),
          _tx(amount: -60, account: 'checking', day: 5),
        ],
      );

      final savings = snapshot.savings!;
      expect(savings.balance, closeTo(2500, 0.001));
      expect(savings.changeThisMonth, closeTo(800, 0.001));
      expect(savings.grewThisMonth, isTrue);
      expect(savings.accountCount, 1);
    });

    test('moving savings out is not spending, and moving in is not income', () {
      final snapshot = _snapshot(
        accounts: _accounts,
        transactions: [
          _tx(amount: -300, account: 'savings', day: 6),
          _tx(amount: 300, account: 'checking', day: 6),
        ],
      );

      expect(snapshot.savings!.shrankThisMonth, isTrue);
      expect(snapshot.spentThisMonth, 0);
      expect(snapshot.incomeThisMonth, 0);
    });

    test('an account view only reports that account', () {
      final snapshot = _snapshot(
        accounts: _accounts,
        transactions: [_tx(amount: 400, account: 'savings', day: 9)],
        scope: const AccountDashboardScope('checking'),
      );

      expect(snapshot.savings, isNull);
    });
  });
}

const _accounts = [
  Account(
    id: 'checking',
    name: '360 Checking',
    type: AccountType.checking,
    currentBalance: 800,
  ),
  Account(
    id: 'savings',
    name: '360 Performance Savings',
    type: AccountType.savings,
    currentBalance: 2500,
  ),
];

DashboardSnapshot _snapshot({
  required List<Account> accounts,
  required List<Transaction> transactions,
  DashboardScope scope = const GlobalDashboardScope(),
}) {
  return buildDashboardSnapshot(
    scope: scope,
    reference: DateTime(2026, 7, 15),
    accounts: accounts,
    allTransactions: transactions,
    scopedTransactions: transactions,
    categoryOverrides: const {},
    categoryDisplayRenamesLower: const {},
    scopedBalanceFromStatement: null,
  );
}

Transaction _tx({
  required double amount,
  required String account,
  required int day,
  int month = 7,
  bool pending = false,
}) {
  final label = amount >= 0 ? 'Transfer In' : 'Transfer Out';
  return Transaction(
    date: DateTime(2026, month, day),
    description: amount >= 0
        ? 'Deposit from 360 Checking ***********'
        : 'Withdrawal to 360 Checking ***********',
    amount: amount,
    accountId: account,
    categoryLabel: label,
    fingerprint: '$account-$amount-$month-$day',
    pending: pending,
  );
}
