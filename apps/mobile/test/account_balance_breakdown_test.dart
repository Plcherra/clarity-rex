import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/dashboard/domain/account_balance_breakdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('account balance breakdown', () {
    test('splits cash, card debt, leftover credit, and net', () {
      final breakdown = buildAccountBalanceBreakdown(
        accounts: const [
          Account(
            id: 'cap-checking',
            name: 'Checking',
            type: AccountType.checking,
            currentBalance: 4.47,
          ),
          Account(
            id: 'cap-savings',
            name: 'Savings',
            type: AccountType.savings,
            currentBalance: 152.45,
          ),
          Account(
            id: 'boa-checking',
            name: 'Checking',
            type: AccountType.checking,
            currentBalance: 89.66,
          ),
          Account(
            id: 'cap-card',
            name: 'Quicksilver',
            type: AccountType.creditCard,
            currentBalance: 270.68,
          ),
          Account(
            id: 'boa-card',
            name: 'Cash Rewards',
            type: AccountType.creditCard,
            currentBalance: 0,
            plaidAvailableBalance: 500,
          ),
        ],
        signedBalanceFor: signedBalanceFromCurrent,
      );

      expect(breakdown.cashTotal, closeTo(246.58, 0.001));
      expect(breakdown.debtTotal, closeTo(270.68, 0.001));
      expect(breakdown.netBalance, closeTo(-24.10, 0.001));
      expect(breakdown.creditAvailableTotal, closeTo(500, 0.001));
      expect(breakdown.cashAccountCount, 3);
      expect(breakdown.creditAccountCount, 2);
    });

    test('does not invent leftover credit when no card reports it', () {
      final breakdown = buildAccountBalanceBreakdown(
        accounts: const [
          Account(
            id: 'checking',
            name: 'Checking',
            type: AccountType.checking,
            currentBalance: 80,
          ),
          Account(
            id: 'card',
            name: 'Card',
            type: AccountType.creditCard,
            currentBalance: 40,
          ),
        ],
        signedBalanceFor: signedBalanceFromCurrent,
      );

      expect(breakdown.cashTotal, 80);
      expect(breakdown.debtTotal, 40);
      expect(breakdown.netBalance, 40);
      expect(breakdown.creditAvailableTotal, isNull);
    });

    test('an account view only reports that account', () {
      final breakdown = buildAccountBalanceBreakdown(
        accounts: const [
          Account(
            id: 'card',
            name: 'Card',
            type: AccountType.creditCard,
            currentBalance: 40,
            plaidAvailableBalance: 500,
          ),
        ],
        signedBalanceFor: signedBalanceFromCurrent,
      );

      expect(breakdown.cashTotal, 0);
      expect(breakdown.debtTotal, 40);
      expect(breakdown.creditAvailableTotal, 500);
    });

    test('falls back to credit limit minus owed when available is missing', () {
      expect(
        creditRemainingForAccount(
          const Account(
            id: 'cap-card',
            name: 'Quicksilver',
            type: AccountType.creditCard,
            currentBalance: 270.68,
            plaidCreditLimit: 900,
          ),
        ),
        closeTo(629.32, 0.001),
      );
    });

    test('ignores available that just copies the amount owed', () {
      expect(
        creditRemainingForAccount(
          const Account(
            id: 'cap-card',
            name: 'Quicksilver',
            type: AccountType.creditCard,
            currentBalance: 270.68,
            plaidAvailableBalance: 270.68,
            plaidCreditLimit: 900,
          ),
        ),
        closeTo(629.32, 0.001),
      );
    });

    test('adds Capital One leftover from limit into the credit-left total', () {
      final breakdown = buildAccountBalanceBreakdown(
        accounts: const [
          Account(
            id: 'cap-card',
            name: 'Quicksilver',
            type: AccountType.creditCard,
            currentBalance: 270.68,
            plaidAvailableBalance: 270.68,
            plaidCreditLimit: 900,
          ),
          Account(
            id: 'boa-card',
            name: 'Cash Rewards',
            type: AccountType.creditCard,
            currentBalance: 0,
            plaidAvailableBalance: 500,
          ),
        ],
        signedBalanceFor: signedBalanceFromCurrent,
      );

      expect(breakdown.debtTotal, closeTo(270.68, 0.001));
      expect(breakdown.creditAvailableTotal, closeTo(1129.32, 0.001));
    });
  });
}
