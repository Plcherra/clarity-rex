import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_records.dart';

Transaction transactionFromRecord(
  TransactionRecord record, {
  String? Function(String? id)? categoryNameForId,
}) {
  return Transaction(
    date: record.date,
    description: record.description ?? record.merchant ?? '',
    amount: signedTransactionAmountFromRecord(record),
    accountId: record.accountId,
    categoryLabel: categoryNameForId?.call(record.categoryId),
    importId: record.importId ?? (record.importedFromCsv ? 'csv' : null),
    fingerprint: record.id,
    financialRole: financialRoleFromStorageValue(record.financialRole),
  );
}

double signedTransactionAmountFromRecord(TransactionRecord record) {
  return switch (record.type.trim().toLowerCase()) {
    'expense' => -record.amount.abs(),
    'income' => record.amount.abs(),
    _ => record.amount,
  };
}
