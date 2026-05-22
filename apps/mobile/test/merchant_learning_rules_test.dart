import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/features/transactions/application/category_workflow_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('matchingMerchantTransactionIds', () {
    test('matches normalized merchant variants conservatively', () {
      final ids = matchingMerchantTransactionIds(
        merchantKey: 'dunkin',
        records: [
          _transactionRecord(
            id: 'dunkin-1',
            description: 'DUNKIN #304654 12/31 MOBILE PURCHASE SOMERVILLE MA',
          ),
          _transactionRecord(id: 'dunkin-2', description: 'DD/BR #1234'),
          _transactionRecord(
            id: 'dunkin-3',
            description: "DUNKIN' DONUTS 01/08 CAMBRIDGE MA",
          ),
          _transactionRecord(
            id: 'unrelated',
            description: 'DOLLARTREE 01/08 MOBILE PURCHASE SOMERVILLE MA',
          ),
        ],
      );

      expect(ids, ['dunkin-1', 'dunkin-2', 'dunkin-3']);
    });

    test('keeps aggregator merchants separate by underlying merchant', () {
      final bomDoughIds = matchingMerchantTransactionIds(
        merchantKey: 'bom dough',
        records: [
          _transactionRecord(
            id: 'bom-1',
            description: 'TST* BOM DOUGH 02/28 MOBILE PURCHASE CAMBRIDGE MA',
          ),
          _transactionRecord(
            id: 'bom-2',
            description: 'SQ *BOM DOUGH 02/28 MOBILE PURCHASE CAMBRIDGE MA',
          ),
          _transactionRecord(
            id: 'other-tst',
            description: 'TST* OTHER BAKERY 02/28 MOBILE PURCHASE CAMBRIDGE MA',
          ),
          _transactionRecord(id: 'paypal', description: 'PAYPAL *SPOTIFY 1234'),
        ],
      );

      expect(bomDoughIds, ['bom-1', 'bom-2']);
    });

    test('returns no ids for empty merchant keys', () {
      final ids = matchingMerchantTransactionIds(
        merchantKey: ' ',
        records: [_transactionRecord(id: 'txn-1', description: 'DUNKIN #123')],
      );

      expect(ids, isEmpty);
    });
  });
}

TransactionRecord _transactionRecord({
  required String id,
  required String description,
}) {
  final now = DateTime.utc(2026);
  return TransactionRecord(
    id: id,
    userId: 'user-1',
    accountId: 'account-1',
    categoryId: null,
    amount: 10,
    type: 'expense',
    description: description,
    date: now,
    merchant: description,
    importedFromCsv: true,
    importId: 'import-1',
    createdAt: now,
    updatedAt: now,
  );
}
