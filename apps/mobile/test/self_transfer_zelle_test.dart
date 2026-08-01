import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/transactions/domain/transaction_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

/// Moving savings to the bank that holds the physical card takes three hops:
/// savings to checking inside one bank, then a Zelle to the other bank. None
/// of it is income — it is the same money walking across the user's accounts.
void main() {
  test('a Zelle from the user to the user is not income', () {
    final rows = [
      _tx(
        description: 'Withdrawal to 360 Checking ***********',
        amount: -300,
        account: 'savings',
        category: 'Transfer Out',
      ),
      _tx(
        description: 'Deposit from 360 Performance Savings ***********',
        amount: 300,
        account: 'capitalone',
        category: 'Transfer In',
      ),
      _tx(
        description: 'PEDRO MARTINS',
        amount: -300,
        account: 'capitalone',
        category: 'Transfer Out',
      ),
      _tx(
        description: 'Zelle payment from Pedro Martins Conf# 4ILM5KTAD',
        amount: 300,
        account: 'boa',
        category: 'Income / Zelle Received',
      ),
    ];

    final resolved = resolveTransactions(
      rows,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: {for (final account in _accounts) account.id: account},
      allTransactions: rows,
    );

    final landing = resolved.last;
    expect(landing.countsAsIncome, isFalse);
    expect(landing.countsAsSpend, isFalse);
    expect(landing.displayCategory, 'Transfer In');
  });

  test('a self-Zelle whose sending side never arrived is still not income', () {
    final rows = [
      ..._provenRoundTrip(amount: 300, day: 6),
      ..._provenRoundTrip(amount: 25, day: 2),
      // Only the landing side of this one was imported.
      _tx(
        description: 'Zelle payment from Pedro Martins Conf# 9FALTW9Q5',
        amount: 14,
        account: 'boa',
        category: 'Income / Zelle Received',
        day: 30,
      ),
    ];

    final orphan = _resolve(rows).last;

    expect(orphan.countsAsIncome, isFalse);
    expect(orphan.displayCategory, 'Transfer In');
  });

  test('one reimbursement from a friend is not a rule about that friend', () {
    final rows = [
      _tx(
        description: 'Zelle payment to Antonio Macedo Conf# oldzape2q',
        amount: -120,
        account: 'boa',
        category: 'Transfer Out',
        day: 3,
      ),
      _tx(
        description: 'Zelle payment from Antonio Macedo Conf# kk20zzq1x',
        amount: 120,
        account: 'capitalone',
        category: 'Income / Zelle Received',
        day: 4,
      ),
      _tx(
        description: 'Zelle payment from Antonio Macedo Conf# ww31aab7z',
        amount: 60,
        account: 'capitalone',
        category: 'Income / Zelle Received',
        day: 20,
      ),
    ];

    final laterPayment = _resolve(rows).last;

    expect(laterPayment.countsAsIncome, isTrue);
  });

  test('someone who shares your first name is still someone else', () {
    final rows = [
      ..._provenRoundTrip(amount: 300, day: 6),
      ..._provenRoundTrip(amount: 25, day: 2),
      _tx(
        description: 'Zelle payment to Pedro Cherra Conf# c1aob5wvq',
        amount: -200,
        account: 'boa',
        category: 'Shopping',
        day: 21,
      ),
    ];

    final toSomeoneElse = _resolve(rows).last;

    expect(toSomeoneElse.countsAsSpend, isTrue);
  });
}

/// One proven move: sent from Capital One, landed at Bank of America.
List<Transaction> _provenRoundTrip({required double amount, required int day}) {
  return [
    _tx(
      description: 'PEDRO MARTINS',
      amount: -amount,
      account: 'capitalone',
      category: 'Transfer Out',
      day: day,
    ),
    _tx(
      description: 'Zelle payment from Pedro Martins Conf# X$day',
      amount: amount,
      account: 'boa',
      category: 'Income / Zelle Received',
      day: day,
    ),
  ];
}

List<ResolvedTransaction> _resolve(List<Transaction> rows) {
  return resolveTransactions(
    rows,
    categoryOverrides: const {},
    categoryDisplayRenamesLower: const {},
    accountsById: {for (final account in _accounts) account.id: account},
    allTransactions: rows,
  );
}

const _accounts = [
  Account(id: 'boa', name: 'Adv Plus Banking', type: AccountType.checking),
  Account(id: 'capitalone', name: '360 Checking', type: AccountType.checking),
  Account(
    id: 'savings',
    name: '360 Performance Savings',
    type: AccountType.savings,
  ),
];

Transaction _tx({
  required String description,
  required double amount,
  required String account,
  String? category,
  int day = 6,
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
