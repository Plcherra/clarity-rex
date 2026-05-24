import 'package:clarity/core/models/transaction.dart';
import 'package:clarity/features/dashboard/domain/dashboard_transaction_groups.dart';
import 'package:clarity/features/transactions/domain/spend_categories.dart';
import 'package:clarity/features/transactions/domain/transaction_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'spending category groups exclude income ignored and unresolved rows',
    () {
      final groups = spendingCategoryGroupsForResolvedTransactions([
        _resolved(
          description: 'TST* BOM DOUGH',
          amount: -4,
          category: 'Coffee / Quick Food',
          countsAsSpend: true,
        ),
        _resolved(
          description: 'PEARL ST MARKET',
          amount: -6,
          category: 'Grocery / Supermarket',
          countsAsSpend: true,
        ),
        _resolved(
          description: 'PAYROLL',
          amount: 1000,
          category: 'Income / Payroll',
          countsAsIncome: true,
        ),
        _resolved(
          description: 'REVERSAL',
          amount: 4,
          category: kIgnoredCategoryLabel,
        ),
        _resolved(
          description: 'UNKNOWN MERCHANT',
          amount: -12,
          category: 'Unknown',
          countsAsSpend: true,
          needsCategorization: true,
        ),
      ]);

      expect(groups.map((group) => group.category), [
        'Grocery / Supermarket',
        'Coffee / Quick Food',
      ]);
      expect(groups.first.amountLabel, 'Spent');
      expect(groups.first.transactionCount, 1);
      expect(groups.first.spending, 6);
    },
  );

  test('spending category groups sum matching spend rows', () {
    final groups = spendingCategoryGroupsForResolvedTransactions([
      _resolved(
        description: 'TST* BOM DOUGH',
        amount: -4,
        category: 'Coffee / Quick Food',
        countsAsSpend: true,
      ),
      _resolved(
        description: 'DUNKIN',
        amount: -5.25,
        category: 'Coffee / Quick Food',
        countsAsSpend: true,
      ),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.category, 'Coffee / Quick Food');
    expect(groups.single.transactionCount, 2);
    expect(groups.single.spending, 9.25);
  });
}

ResolvedTransaction _resolved({
  required String description,
  required double amount,
  required String category,
  bool countsAsSpend = false,
  bool countsAsIncome = false,
  bool needsCategorization = false,
}) {
  final transaction = Transaction(
    date: DateTime(2026, 3, 2),
    description: description,
    amount: amount,
    accountId: 'account-1',
    categoryLabel: category,
  );
  return ResolvedTransaction(
    transaction: transaction,
    canonicalCategory: category,
    displayCategory: category,
    financialRole: countsAsIncome
        ? FinancialRole.income
        : FinancialRole.expense,
    isStatementDataRow: true,
    countsAsSpend: countsAsSpend,
    countsAsIncome: countsAsIncome,
    needsCategorization: needsCategorization,
  );
}
