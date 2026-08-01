import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:clarity/features/dashboard/domain/monthly_cash_flow_series.dart';
import 'package:clarity/features/transactions/domain/transaction_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('monthly cash flow series', () {
    test('paying the credit card is not income and not a second expense', () {
      final snapshot = _snapshot([
        _tx(
          description: 'PAYROLL DIRECT DEP',
          account: 'checking',
          amount: 1942.53,
          day: 1,
        ),
        _tx(
          description: 'PUBLIX 1234',
          account: 'checking',
          amount: -480.35,
          day: 3,
          category: 'Grocery / Supermarket',
        ),
        // The same money leaving checking and landing on the card.
        _tx(
          description: 'ONLINE BANKING PAYMENT TO CRD VISA',
          account: 'checking',
          amount: -900,
          day: 20,
          category: 'Credit Card Payment',
        ),
        _tx(
          description: 'THANK YOU PAYMENT RECEIVED',
          account: 'visa',
          amount: 900,
          day: 20,
          category: 'Credit Card Payment',
        ),
      ]);

      final july = snapshot.monthlyCashFlow.single;

      expect(july.income, closeTo(1942.53, 0.001));
      expect(july.spend, closeTo(480.35, 0.001));
    });

    test('a charted month matches the overview card for that month', () {
      final snapshot = _snapshot([
        _tx(
          description: 'PAYROLL DIRECT DEP',
          account: 'checking',
          amount: 1942.53,
          day: 1,
        ),
        _tx(
          description: 'AMAZON MKTPL',
          account: 'checking',
          amount: -632.89,
          day: 4,
          category: 'Shopping',
        ),
        _tx(
          description: 'TRANSFER TO SAVINGS',
          account: 'checking',
          amount: -300,
          day: 10,
          category: 'Transfer Out',
        ),
        _tx(
          description: 'TRANSFER FROM CHECKING',
          account: 'savings',
          amount: 300,
          day: 10,
        ),
      ]);

      final july = snapshot.monthlyCashFlow.single;

      expect(july.income, snapshot.incomeThisMonth);
      expect(july.spend, snapshot.spentThisMonth);
      expect(july.net, closeTo(snapshot.availableThisMonth, 0.001));
    });

    test('pending rows stay out until they settle', () {
      final snapshot = _snapshot([
        _tx(
          description: 'AMAZON MKTPL',
          account: 'checking',
          amount: -50,
          day: 2,
          category: 'Shopping',
        ),
        _tx(
          description: 'HOTEL HOLD',
          account: 'checking',
          amount: -500,
          day: 3,
          category: 'Shopping',
          pending: true,
        ),
      ]);

      expect(snapshot.monthlyCashFlow.single.spend, closeTo(50, 0.001));
    });

    test('months come back oldest first, capped to the last twelve', () {
      final transactions = [
        for (var month = 1; month <= 14; month++)
          _tx(
            description: 'AMAZON MKTPL',
            account: 'checking',
            amount: -10,
            day: 5,
            category: 'Shopping',
            date: DateTime(2025, month, 5),
          ),
      ];

      final series = buildMonthlyCashFlowSeries(_resolve(transactions));

      expect(series, hasLength(12));
      expect(series.first.yearMonth, '2025-03');
      expect(series.last.yearMonth, '2026-02');
    });
  });
}

const _accounts = [
  Account(id: 'checking', name: 'Checking', type: AccountType.checking),
  Account(id: 'savings', name: 'Savings', type: AccountType.savings),
  Account(id: 'visa', name: 'Visa', type: AccountType.creditCard),
];

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

List<ResolvedTransaction> _resolve(List<Transaction> transactions) {
  return resolveTransactions(
    transactions,
    categoryOverrides: const {},
    categoryDisplayRenamesLower: const {},
    accountsById: {for (final account in _accounts) account.id: account},
    allTransactions: transactions,
  );
}

Transaction _tx({
  required String description,
  required String account,
  required double amount,
  required int day,
  String? category,
  bool pending = false,
  DateTime? date,
}) {
  return Transaction(
    date: date ?? DateTime(2026, 7, day),
    description: description,
    amount: amount,
    accountId: account,
    categoryLabel: category,
    fingerprint: '$account-$description-$amount',
    pending: pending,
  );
}
