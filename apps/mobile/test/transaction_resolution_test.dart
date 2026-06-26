import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/categories/domain/category_normalization.dart';
import 'package:clarity/features/transactions/domain/spend_categories.dart';
import 'package:clarity/features/transactions/domain/transaction_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('financial role storage values round-trip supported roles', () {
    for (final role in FinancialRole.values) {
      expect(
        financialRoleFromStorageValue(financialRoleToStorageValue(role)),
        role,
      );
    }
    expect(financialRoleFromStorageValue(null), isNull);
    expect(
      financialRoleFromStorageValue('credit card payment'),
      FinancialRole.creditCardPayment,
    );
  });

  test('ignored category overrides expense sign for fetched rows', () {
    final transaction = Transaction(
      date: DateTime(2026, 3, 4),
      description: 'BANK RETURNED ITEM FEE REVERSAL',
      amount: -35,
      accountId: 'checking',
      categoryLabel: kIgnoredCategoryLabel,
      fingerprint: 'tx-ignored',
    );

    final resolved = resolveTransaction(
      t: transaction,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: const {},
      allTransactions: [transaction],
    );

    expect(resolved.financialRole, FinancialRole.adjustment);
    expect(resolved.countsAsSpend, isFalse);
    expect(resolved.countsAsIncome, isFalse);
  });

  test('positive refund descriptions do not count as income', () {
    final transaction = Transaction(
      date: DateTime(2026, 3, 5),
      description: 'MERCHANT REFUND REVERSAL',
      amount: 14.99,
      accountId: 'checking',
      categoryLabel: 'Shopping',
      fingerprint: 'tx-refund',
    );

    final resolved = resolveTransaction(
      t: transaction,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: const {},
      allTransactions: [transaction],
    );

    expect(resolved.financialRole, FinancialRole.refund);
    expect(resolved.countsAsSpend, isFalse);
    expect(resolved.countsAsIncome, isFalse);
  });

  test('transfer out category does not count as spend', () {
    final transaction = Transaction(
      date: DateTime(2026, 3, 6),
      description: 'ZELLE PAYMENT TO FAMILY',
      amount: -120,
      accountId: 'checking',
      categoryLabel: 'Transfer Out',
      fingerprint: 'tx-transfer',
    );

    final resolved = resolveTransaction(
      t: transaction,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: const {},
      allTransactions: [transaction],
    );

    expect(resolved.financialRole, FinancialRole.transfer);
    expect(resolved.countsAsSpend, isFalse);
    expect(resolved.countsAsIncome, isFalse);
  });

  test('confirmed credit card payment does not count as spend', () {
    final checkingPayment = Transaction(
      date: DateTime(2026, 3, 7),
      description: 'ONLINE BANKING PAYMENT TO CRD VISA',
      amount: -250,
      accountId: 'checking',
      categoryLabel: 'Credit Card Payment',
      fingerprint: 'tx-checking-payment',
    );
    final cardPayment = Transaction(
      date: DateTime(2026, 3, 8),
      description: 'THANK YOU PAYMENT RECEIVED',
      amount: 250,
      accountId: 'visa',
      categoryLabel: 'Credit Card Payment',
      fingerprint: 'tx-card-payment',
    );
    final accountsById = {
      'checking': const Account(
        id: 'checking',
        name: 'Bank of America',
        type: AccountType.checking,
      ),
      'visa': const Account(
        id: 'visa',
        name: 'Visa',
        type: AccountType.creditCard,
      ),
    };

    final resolved = resolveTransactions(
      [checkingPayment, cardPayment],
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: accountsById,
      allTransactions: [checkingPayment, cardPayment],
    );

    final source = resolved.first;
    expect(source.financialRole, FinancialRole.creditCardPayment);
    expect(source.countsAsSpend, isFalse);
    expect(source.countsAsIncome, isFalse);
  });

  test('unknown statement rows resolve to automatic fallback category', () {
    final transaction = Transaction(
      date: DateTime(2026, 3, 9),
      description: 'MYSTERY POS PURCHASE',
      amount: -12.34,
      accountId: 'checking',
      categoryLabel: kUnknownCategoryName,
      fingerprint: 'tx-unknown',
    );

    final resolved = resolveTransaction(
      t: transaction,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: const {},
      allTransactions: [transaction],
    );

    expect(resolved.displayCategory, kBestEffortExpenseCategoryName);
    expect(resolved.needsCategorization, isFalse);
  });

  test('unconfirmed credit card payments stay expenses until matched', () {
    final transaction = Transaction(
      date: DateTime(2026, 3, 10),
      description: 'ONLINE BANKING PAYMENT TO CRD VISA',
      amount: -250,
      accountId: 'checking',
      categoryLabel: 'Credit Card Payment',
      fingerprint: 'tx-unconfirmed-card-payment',
    );

    final resolved = resolveTransaction(
      t: transaction,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: const {},
      allTransactions: [transaction],
    );

    expect(resolved.financialRole, FinancialRole.expense);
    expect(resolved.countsAsSpend, isTrue);
  });

  test('manual financial roles are preserved on resolved transactions', () {
    final transaction = Transaction(
      date: DateTime(2026, 3, 11),
      description: 'MANUAL TRANSFER OVERRIDE',
      amount: -42,
      accountId: 'checking',
      categoryLabel: 'Transfer Out',
      financialRole: FinancialRole.transfer,
      fingerprint: 'tx-manual-role',
    );

    final resolved = resolveTransaction(
      t: transaction,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: const {},
      allTransactions: [transaction],
    );

    expect(resolved.financialRole, FinancialRole.transfer);
    expect(resolved.transaction.financialRole, FinancialRole.transfer);
  });
}
