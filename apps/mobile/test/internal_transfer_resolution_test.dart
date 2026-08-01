import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/categories/domain/category_normalization.dart';
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

  group('moving your own money between your own accounts', () {
    const accountsById = {
      'savings': Account(
        id: 'savings',
        name: '360 Performance Savings',
        type: AccountType.savings,
      ),
      'checking': Account(
        id: 'checking',
        name: '360 Checking',
        type: AccountType.checking,
      ),
      'other-bank': Account(
        id: 'other-bank',
        name: 'Adv Plus Banking',
        type: AccountType.checking,
      ),
    };

    /// Savings and checking at one bank, then out to a second bank by Zelle,
    /// because that is the leg that arrives without a fee and in real time.
    List<Transaction> chain({required bool towardsOtherBank}) {
      final home = towardsOtherBank ? 'savings' : 'other-bank';
      final away = towardsOtherBank ? 'other-bank' : 'savings';
      return [
        Transaction(
          date: DateTime(2026, 7, 8),
          description: towardsOtherBank
              ? 'Withdrawal to 360 Checking'
              : 'Zelle payment to Pedro Martins',
          amount: -300,
          accountId: home,
          categoryLabel: 'Transfer Out',
          fingerprint: 'leg-1-out',
        ),
        Transaction(
          date: DateTime(2026, 7, 8),
          description: towardsOtherBank
              ? 'Deposit from 360 Performance Savings'
              : 'Zelle payment from Pedro Martins',
          amount: 300,
          accountId: 'checking',
          categoryLabel: 'Transfer In',
          fingerprint: 'leg-1-in',
        ),
        Transaction(
          date: DateTime(2026, 7, 8),
          description: towardsOtherBank
              ? 'Zelle payment to Pedro Martins'
              : 'Withdrawal to 360 Performance Savings',
          amount: -300,
          accountId: 'checking',
          categoryLabel: 'Transfer Out',
          fingerprint: 'leg-2-out',
        ),
        Transaction(
          date: DateTime(2026, 7, 8),
          description: towardsOtherBank
              ? 'Zelle payment from Pedro Martins'
              : 'Deposit from 360 Checking',
          amount: 300,
          accountId: away,
          categoryLabel: 'Transfer In',
          fingerprint: 'leg-2-in',
        ),
      ];
    }

    for (final towardsOtherBank in [true, false]) {
      final direction = towardsOtherBank ? 'out to' : 'back from';
      test('a $direction the second bank is neither income nor spend', () {
        final transactions = chain(towardsOtherBank: towardsOtherBank);

        final resolved = resolveTransactions(
          transactions,
          categoryOverrides: const {},
          categoryDisplayRenamesLower: const {},
          accountsById: accountsById,
          allTransactions: transactions,
        );

        for (final row in resolved) {
          expect(
            row.financialRole,
            FinancialRole.transfer,
            reason: '${row.transaction.fingerprint} moved the user\'s own money',
          );
          expect(row.countsAsIncome, isFalse);
          expect(row.countsAsSpend, isFalse);
        }
      });
    }

    test('a leg whose other side has not synced yet is still a transfer', () {
      final lonelyLeg = Transaction(
        date: DateTime(2026, 7, 31),
        description: 'Withdrawal to 360 Performance Savings',
        amount: -30,
        accountId: 'checking',
        categoryLabel: 'Transfer Out',
        fingerprint: 'tx-unsynced-leg',
      );

      final resolved = resolveTransaction(
        t: lonelyLeg,
        categoryOverrides: const {},
        categoryDisplayRenamesLower: const {},
        accountsById: accountsById,
        allTransactions: [lonelyLeg],
      );

      expect(resolved.financialRole, FinancialRole.transfer);
      expect(resolved.countsAsSpend, isFalse);
    });

    test('the two sides may carry different names for the same person', () {
      // One bank has the user's phone on file, the other their email, so the
      // same person appears under two names. Both accounts are the user's.
      final sent = Transaction(
        date: DateTime(2026, 7, 21),
        description: 'Zelle payment to Pedro Cherra Conf# c1aob5wvq',
        amount: -200,
        accountId: 'other-bank',
        categoryLabel: 'Transfer Out',
        fingerprint: 'tx-alias-out',
      );
      final received = Transaction(
        date: DateTime(2026, 7, 21),
        description: 'PEDRO MARTINS',
        amount: 200,
        accountId: 'checking',
        categoryLabel: 'Transfer In',
        fingerprint: 'tx-alias-in',
      );
      final transactions = [sent, received];

      final resolved = resolveTransactions(
        transactions,
        categoryOverrides: const {},
        categoryDisplayRenamesLower: const {},
        accountsById: accountsById,
        allTransactions: transactions,
      );

      for (final row in resolved) {
        expect(row.financialRole, FinancialRole.transfer);
        expect(row.countsAsSpend, isFalse);
        expect(row.countsAsIncome, isFalse);
      }
    });

    test('rent sent by Zelle is spend, not a transfer', () {
      final rent = Transaction(
        date: DateTime(2026, 7, 1),
        description: 'Zelle payment to Antonio Macedo',
        amount: -1150,
        accountId: 'checking',
        categoryLabel: 'Transfer Out',
        fingerprint: 'tx-rent',
      );

      final resolved = resolveTransaction(
        t: rent,
        categoryOverrides: const {},
        categoryDisplayRenamesLower: const {},
        accountsById: accountsById,
        allTransactions: [rent],
      );

      expect(resolved.financialRole, FinancialRole.expense);
      expect(resolved.countsAsSpend, isTrue);
    });
  });

  test('both halves of a split paycheck count as income', () {
    // One bank prints the payroll envelope, the other prints a bare merchant
    // name — which is the employer's shop, so it inherits the category of
    // buying there. Two feeds, a cent apart, not a duplicate.
    final describedHalf = Transaction(
      date: DateTime(2026, 7, 23),
      description: 'BOM DOUGH LLC DES:PAYROLL ID:1047 INDN:MARTINS PEDRO',
      amount: 30.82,
      accountId: 'other-bank',
      categoryLabel: 'Income / Payroll',
      fingerprint: 'tx-payroll-described',
    );
    final bareHalf = Transaction(
      date: DateTime(2026, 7, 23),
      description: 'Bom Dough LLC',
      amount: 30.81,
      accountId: 'checking',
      categoryLabel: 'Coffee / Quick Food',
      fingerprint: 'tx-payroll-bare',
    );
    final transactions = [describedHalf, bareHalf];

    final resolved = resolveTransactions(
      transactions,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: const {
        'checking': Account(
          id: 'checking',
          name: '360 Checking',
          type: AccountType.checking,
        ),
        'other-bank': Account(
          id: 'other-bank',
          name: 'Adv Plus Banking',
          type: AccountType.checking,
        ),
      },
      allTransactions: transactions,
    );

    for (final row in resolved) {
      expect(row.financialRole, FinancialRole.income);
      expect(row.countsAsIncome, isTrue);
      expect(row.displayCategory, 'Income / Payroll');
    }
  });
}
