import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/transactions/domain/transaction_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

/// A split direct deposit: the employer sends half to each bank, and only one
/// bank spells out `PAYROLL`. The quiet half used to inherit the category of
/// buying at that merchant, so a paycheck disappeared into a spending bucket.
void main() {
  group('deposits from someone who pays you', () {
    test('the bare half of a split paycheck is pay, not coffee', () {
      final rows = [
        _tx(
          description:
              'Bom Dough LLC DES:PAYROLL ID:1047 INDN:Martins Pedro CO ID:XXXXX30473 PPD',
          amount: 632.54,
          account: 'boa',
        ),
        _tx(
          description: 'Bom Dough LLC',
          amount: 632.54,
          account: 'capitalone',
          category: 'Coffee / Quick Food',
        ),
      ];

      final quietHalf = _resolve(rows).last;

      expect(quietHalf.countsAsIncome, isTrue);
      expect(quietHalf.countsAsSpend, isFalse);
      expect(quietHalf.displayCategory, 'Income / Payroll');
    });

    test('buying at the same shop is still spending', () {
      final rows = [
        _tx(
          description: 'Bom Dough LLC DES:PAYROLL ID:1047 INDN:Martins Pedro',
          amount: 632.54,
          account: 'boa',
        ),
        _tx(
          description: 'BOM DOUGH COFFEE MIAMI FL',
          amount: -6.25,
          account: 'capitalone',
          category: 'Coffee / Quick Food',
        ),
      ];

      final coffee = _resolve(rows).last;

      expect(coffee.countsAsSpend, isTrue);
      expect(coffee.countsAsIncome, isFalse);
      expect(coffee.displayCategory, 'Coffee / Quick Food');
    });

    test('a deposit from someone who has never paid is left alone', () {
      final rows = [
        _tx(
          description: 'Bom Dough LLC DES:PAYROLL ID:1047 INDN:Martins Pedro',
          amount: 632.54,
          account: 'boa',
        ),
        _tx(
          description: 'FRAGRANCENET COM',
          amount: 119.13,
          account: 'boa',
          category: 'Shopping',
        ),
      ];

      final mystery = _resolve(rows).last;

      expect(mystery.countsAsIncome, isFalse);
      expect(mystery.displayCategory, 'Shopping');
    });

    test('money the user moves between own accounts is still a transfer', () {
      final rows = [
        _tx(
          description: 'Bom Dough LLC DES:PAYROLL ID:1047 INDN:Martins Pedro',
          amount: 632.54,
          account: 'boa',
        ),
        _tx(
          description: 'Deposit from 360 Performance Savings',
          amount: 300,
          account: 'capitalone',
          category: 'Transfer In',
        ),
      ];

      final transfer = _resolve(rows).last;

      expect(transfer.countsAsIncome, isFalse);
      expect(transfer.displayCategory, 'Transfer In');
    });

    test('card rewards are not earnings', () {
      final rows = [
        _tx(
          description: 'CASH REWARDS STATEMENT CREDIT',
          amount: 10.66,
          account: 'visa',
          category: 'Income / Payroll',
        ),
      ];

      final reward = _resolve(rows).single;

      expect(reward.countsAsIncome, isFalse);
      expect(reward.countsAsSpend, isFalse);
    });

    test('a refund from the employer is not counted as wages', () {
      final rows = [
        _tx(
          description: 'Bom Dough LLC DES:PAYROLL ID:1047 INDN:Martins Pedro',
          amount: 632.54,
          account: 'boa',
        ),
        _tx(
          description: 'Bom Dough LLC REFUND',
          amount: 12.50,
          account: 'capitalone',
          category: 'Coffee / Quick Food',
        ),
      ];

      final refund = _resolve(rows).last;

      expect(refund.countsAsIncome, isFalse);
      expect(refund.countsAsSpend, isFalse);
    });
  });
}

const _accounts = [
  Account(id: 'boa', name: 'Adv Plus Banking', type: AccountType.checking),
  Account(id: 'capitalone', name: '360 Checking', type: AccountType.checking),
  Account(id: 'visa', name: 'Cash Rewards', type: AccountType.creditCard),
];

List<ResolvedTransaction> _resolve(List<Transaction> rows) {
  return resolveTransactions(
    rows,
    categoryOverrides: const {},
    categoryDisplayRenamesLower: const {},
    accountsById: {for (final account in _accounts) account.id: account},
    allTransactions: rows,
  );
}

Transaction _tx({
  required String description,
  required double amount,
  required String account,
  String? category,
  int day = 9,
}) {
  return Transaction(
    date: DateTime(2026, 7, day),
    description: description,
    amount: amount,
    accountId: account,
    categoryLabel: category,
    fingerprint: '$account-$description-$amount',
  );
}
