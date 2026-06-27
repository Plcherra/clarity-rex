import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/categories/domain/category_normalization.dart';
import 'package:clarity/features/transactions/domain/spend_categories.dart';
import 'package:clarity/features/transactions/domain/transaction_resolution.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('transfer in descriptions do not count as income', () {
    final transaction = Transaction(
      date: DateTime(2026, 6, 10),
      description: 'ONLINE TRANSFER FROM SAV 1234',
      amount: 500,
      accountId: 'checking',
      fingerprint: 'tx-transfer-in',
    );

    final resolved = resolveTransaction(
      t: transaction,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: const {
        'checking': Account(
          id: 'checking',
          name: 'Checking',
          type: AccountType.checking,
        ),
      },
      allTransactions: [transaction],
    );

    expect(resolved.displayCategory, 'Transfer In');
    expect(resolved.financialRole, FinancialRole.transfer);
    expect(resolved.countsAsIncome, isFalse);
    expect(resolved.countsAsSpend, isFalse);
  });

  test('matched checking and savings rows count as transfer not income', () {
    final savingsOut = Transaction(
      date: DateTime(2026, 6, 11),
      description: 'TRANSFER TO CHECKING',
      amount: -400,
      accountId: 'savings',
      categoryLabel: 'Transfer Out',
      fingerprint: 'tx-savings-out',
    );
    final checkingIn = Transaction(
      date: DateTime(2026, 6, 11),
      description: 'TRANSFER FROM SAVINGS',
      amount: 400,
      accountId: 'checking',
      fingerprint: 'tx-checking-in',
    );
    final accountsById = {
      'checking': const Account(
        id: 'checking',
        name: 'Checking',
        type: AccountType.checking,
      ),
      'savings': const Account(
        id: 'savings',
        name: 'Savings',
        type: AccountType.savings,
      ),
    };

    final resolved = resolveTransactions(
      [savingsOut, checkingIn],
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: accountsById,
      allTransactions: [savingsOut, checkingIn],
    );

    final inflow = resolved.singleWhere(
      (row) => row.transaction.fingerprint == 'tx-checking-in',
    );
    expect(inflow.financialRole, FinancialRole.transfer);
    expect(inflow.countsAsIncome, isFalse);
  });

  test('unknown positive inflows do not default to payroll income', () {
    final transaction = Transaction(
      date: DateTime(2026, 6, 12),
      description: 'MYSTERY DEPOSIT',
      amount: 75,
      accountId: 'checking',
      categoryLabel: 'Unknown',
      fingerprint: 'tx-unknown-in',
    );

    final resolved = resolveTransaction(
      t: transaction,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: const {
        'checking': Account(
          id: 'checking',
          name: 'Checking',
          type: AccountType.checking,
        ),
      },
      allTransactions: [transaction],
    );

    expect(resolved.displayCategory, kAutomaticFallbackCategoryName);
    expect(resolved.countsAsIncome, isFalse);
  });

  test('credit card payment inflow is confirmed and excluded from income', () {
    final checkingPayment = Transaction(
      date: DateTime(2026, 6, 13),
      description: 'ONLINE BANKING PAYMENT TO CRD VISA',
      amount: -250,
      accountId: 'checking',
      categoryLabel: 'Credit Card Payment',
      fingerprint: 'tx-checking-payment',
    );
    final cardPayment = Transaction(
      date: DateTime(2026, 6, 13),
      description: 'THANK YOU PAYMENT RECEIVED',
      amount: 250,
      accountId: 'visa',
      categoryLabel: 'Credit Card Payment',
      fingerprint: 'tx-card-payment',
    );
    final accountsById = {
      'checking': const Account(
        id: 'checking',
        name: 'Checking',
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

    final cardIn = resolved.singleWhere(
      (row) => row.transaction.fingerprint == 'tx-card-payment',
    );
    expect(cardIn.financialRole, FinancialRole.creditCardPayment);
    expect(cardIn.countsAsIncome, isFalse);
  });
}
