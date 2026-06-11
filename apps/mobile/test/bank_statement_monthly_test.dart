import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/transactions/domain/bank_statement_monthly.dart';
import 'package:clarity/features/transactions/domain/transaction_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'month groups keep Plaid balance descriptions and filter CSV summaries',
    () {
      final groups = monthlyGroupsFromTransactions([
        _transaction(
          description: 'BALANCE TRANSFER PAYMENT',
          amount: -150,
          source: 'plaid',
        ),
        _transaction(
          description: 'Ending Balance',
          amount: 1200,
          source: 'csv',
          importId: 'import-1',
        ),
        _transaction(
          description: 'Total Credits',
          amount: 3000,
          source: 'csv',
          importId: 'import-1',
        ),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.yearMonth, '2026-06');
      expect(groups.single.transactions, hasLength(1));
      expect(
        groups.single.transactions.single.transaction.description,
        'BALANCE TRANSFER PAYMENT',
      );
      expect(groups.single.totalAmount, -150);
    },
  );

  test('resolved month groups keep pending Plaid rows visible', () {
    final groups = monthlyGroupsFromResolvedTransactions([
      _resolved(
        _transaction(
          description: 'PENDING BALANCE TRANSFER',
          amount: -45,
          source: 'plaid',
          pending: true,
        ),
      ),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.transactions, hasLength(1));
    expect(groups.single.transactions.single.transaction.pending, isTrue);
    expect(groups.single.totalAmount, -45);
  });

  test('CSV balance rows are not statement data rows', () {
    expect(
      isBankStatementDataRow(
        _transaction(
          description: 'Balance Forward',
          amount: 1200,
          source: 'csv',
          importId: 'import-1',
        ),
      ),
      isFalse,
    );
  });

  test('Plaid balance rows are statement data rows', () {
    expect(
      isBankStatementDataRow(
        _transaction(
          description: 'Balance Transfer',
          amount: -75,
          source: 'plaid',
        ),
      ),
      isTrue,
    );
  });
}

Transaction _transaction({
  required String description,
  required double amount,
  required String source,
  String? importId,
  bool pending = false,
}) {
  return Transaction(
    date: DateTime(2026, 6, 12),
    description: description,
    amount: amount,
    accountId: 'checking',
    categoryLabel: 'Transfer',
    importId: importId,
    source: source,
    pending: pending,
  );
}

ResolvedTransaction _resolved(Transaction transaction) {
  return ResolvedTransaction(
    transaction: transaction,
    canonicalCategory: 'Transfer',
    displayCategory: 'Transfer',
    financialRole: FinancialRole.transfer,
    isStatementDataRow: true,
    countsAsSpend: false,
    countsAsIncome: false,
    needsCategorization: false,
  );
}
