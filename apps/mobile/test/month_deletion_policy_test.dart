import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/dashboard/domain/month_deletion_policy.dart';
import 'package:clarity/features/transactions/domain/bank_statement_monthly.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('monthDeletionPolicyForLines', () {
    test('allows one-account CSV months', () {
      final policy = monthDeletionPolicyForLines([
        _line(accountId: 'checking', source: 'csv', importId: 'import-1'),
        _line(accountId: 'checking', source: 'manual'),
      ]);

      expect(policy.canDelete, isTrue);
      expect(policy.accountId, 'checking');
      expect(policy.protectionMessage, isNull);
    });

    test('blocks Plaid-only months with resync/disconnect copy', () {
      final policy = monthDeletionPolicyForLines([
        _line(accountId: 'checking', source: 'plaid'),
      ]);

      expect(policy.canDelete, isFalse);
      expect(policy.blockReason, MonthDeletionBlockReason.plaidSynced);
      expect(policy.protectionMessage, contains('resync'));
      expect(policy.protectionMessage, contains('disconnect'));
    });

    test('blocks mixed Plaid and CSV months', () {
      final policy = monthDeletionPolicyForLines([
        _line(accountId: 'checking', source: 'plaid'),
        _line(accountId: 'checking', source: 'csv', importId: 'import-1'),
      ]);

      expect(policy.canDelete, isFalse);
      expect(policy.blockReason, MonthDeletionBlockReason.plaidSynced);
    });

    test('blocks multi-account CSV months', () {
      final policy = monthDeletionPolicyForLines([
        _line(accountId: 'checking', source: 'csv', importId: 'import-1'),
        _line(accountId: 'savings', source: 'csv', importId: 'import-2'),
      ]);

      expect(policy.canDelete, isFalse);
      expect(policy.blockReason, MonthDeletionBlockReason.multipleAccounts);
    });
  });
}

BankStatementLine _line({
  required String accountId,
  required String source,
  String? importId,
}) {
  return BankStatementLine(
    transaction: Transaction(
      date: DateTime(2026, 6, 1),
      description: 'Coffee',
      amount: -4.5,
      accountId: accountId,
      source: source,
      importId: importId,
    ),
    suggestedCategory: 'Coffee / Quick Food',
  );
}
