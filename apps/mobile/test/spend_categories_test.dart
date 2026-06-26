import 'package:clarity/features/transactions/domain/spend_categories.dart';
import 'package:clarity/features/categories/domain/category_normalization.dart';
import 'package:clarity/core/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known merchants use deterministic fallback categories', () {
    expect(
      suggestCategoryFromDescription(
        'DUNKIN #304654 12/31 MOBILE PURCHASE SOMERVILLE MA',
        amount: -4.55,
      ),
      'Coffee / Quick Food',
    );
    expect(
      suggestCategoryFromDescription(
        'TST* BOM DOUGH 02/28 MOBILE PURCHASE CAMBRIDGE MA',
        amount: -2.94,
      ),
      'Coffee / Quick Food',
    );
    expect(
      suggestCategoryFromDescription(
        'DOLLARTREE 01/08 MOBILE PURCHASE SOMERVILLE MA',
        amount: -14.08,
      ),
      'Shopping',
    );
    expect(
      suggestCategoryFromDescription(
        'PEARL ST MARKET 02/28 MOBILE PURCHASE SOMERVILLE MA',
        amount: -6.48,
      ),
      'Grocery / Supermarket',
    );
    expect(
      suggestCategoryFromDescription(
        'BKOFAMERICA ATM 03/02 #XXXXX6083 WITHDRWL EAST CAMBRIDGE MA',
        amount: -10,
      ),
      'Cash Withdrawal',
    );
  });

  test('negative purchases are not categorized as income', () {
    expect(
      suggestCategoryFromDescription(
        'TST* BOM DOUGH - ONE CAN 02/27 MOBILE PURCHASE Cambridge MA',
        amount: -4,
      ),
      isNot(startsWith('Income')),
    );
    expect(
      suggestCategoryFromDescription(
        'INDN:MARTINS PEDRO DES:PAYROLL',
        amount: -100,
      ),
      kBestEffortExpenseCategoryName,
    );
  });

  test('positive payroll and zelle income remain income', () {
    expect(
      suggestCategoryFromDescription(
        'INDN:MARTINS PEDRO DES:PAYROLL',
        amount: 1200,
      ),
      'Income / Payroll',
    );
    expect(
      suggestCategoryFromDescription(
        'Zelle payment from MARCELLA GODOY SILVA',
        amount: 50,
      ),
      'Income / Zelle Received',
    );
  });

  test('stored Unknown category falls through to deterministic category', () {
    final transaction = Transaction(
      date: DateTime(2026, 3, 2),
      description: 'TST* BOM DOUGH 02/28 MOBILE PURCHASE CAMBRIDGE MA',
      amount: -2.94,
      accountId: 'account-1',
      categoryLabel: 'Unknown',
    );

    expect(spendGroupLabel(transaction), 'Coffee / Quick Food');
  });

  test('unknown merchants resolve to a real fallback category', () {
    expect(
      suggestCategoryFromDescription('MYSTERY POS PURCHASE', amount: -12.34),
      kBestEffortExpenseCategoryName,
    );

    final transaction = Transaction(
      date: DateTime(2026, 3, 9),
      description: 'MYSTERY POS PURCHASE',
      amount: -12.34,
      accountId: 'checking',
      categoryLabel: kUnknownCategoryName,
    );

    expect(spendGroupLabel(transaction), kBestEffortExpenseCategoryName);
  });
}
