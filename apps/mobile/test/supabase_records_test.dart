import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TransactionRecord date-only field uses local calendar day at noon', () {
    final record = TransactionRecord.fromJson({
      'id': 'tx-1',
      'user_id': 'user-1',
      'account_id': 'acct-1',
      'category_id': null,
      'amount': 12.34,
      'type': 'expense',
      'description': 'Coffee',
      'date': '2026-06-30',
      'merchant': null,
      'imported_from_csv': false,
      'import_id': null,
      'source': 'manual',
      'pending': false,
      'removed_at': null,
      'created_at': '2026-06-30T12:00:00Z',
      'updated_at': '2026-06-30T12:00:00Z',
    });

    expect(record.date.year, 2026);
    expect(record.date.month, 6);
    expect(record.date.day, 30);
    expect(record.date.hour, 12);
    expect(record.date.isUtc, isFalse);
  });

  test('TransactionRecord datetime fields keep parsed timestamp', () {
    final record = TransactionRecord.fromJson({
      'id': 'tx-2',
      'user_id': 'user-1',
      'account_id': 'acct-1',
      'category_id': null,
      'amount': 5,
      'type': 'expense',
      'description': 'Snack',
      'date': '2026-06-30',
      'merchant': null,
      'imported_from_csv': false,
      'import_id': null,
      'source': 'manual',
      'pending': false,
      'removed_at': null,
      'created_at': '2026-06-30T18:45:00.000Z',
      'updated_at': '2026-06-30T18:45:00.000Z',
    });

    expect(record.createdAt, DateTime.parse('2026-06-30T18:45:00.000Z'));
  });
}
