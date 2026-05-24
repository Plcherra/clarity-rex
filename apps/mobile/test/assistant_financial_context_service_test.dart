import 'package:clarity/core/models/models.dart';
import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/features/assistant/data/financial_context_service.dart';
import 'package:clarity/features/categories/domain/category_normalization.dart';
import 'package:clarity/features/transactions/domain/transaction_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rex transaction context stays bounded and keeps review rows', () {
    final records = [
      for (var i = 0; i < 150; i += 1)
        _record(
          id: 'tx-$i',
          date: DateTime(2026, 1, 1).add(Duration(days: i)),
          categoryId: i == 0 ? 'unknown' : 'food',
        ),
    ];
    final transactions = [
      for (final record in records)
        Transaction(
          date: record.date,
          description: record.description ?? '',
          amount: record.amount,
          accountId: record.accountId,
          categoryLabel: record.categoryId == 'unknown'
              ? kUnknownCategoryName
              : 'Food & Drink',
          fingerprint: record.id,
        ),
    ];
    final resolved = resolveTransactions(
      transactions,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: const {},
      allTransactions: transactions,
    );

    final selected = selectRexTransactionContextRows(
      transactions: records,
      resolvedTransactions: resolved,
      maxRows: 120,
    );

    expect(selected, hasLength(120));
    expect(selected.map((record) => record.id), contains('tx-0'));
    expect(selected.first.id, 'tx-149');
  });

  test(
    'Rex drilldown index summarizes months accounts categories and review',
    () {
      const checking = Account(
        id: 'checking',
        name: 'Checking',
        type: AccountType.checking,
      );
      const card = Account(
        id: 'card',
        name: 'Visa',
        type: AccountType.creditCard,
      );
      final transactions = [
        Transaction(
          date: DateTime(2026, 3, 4),
          description: 'Coffee',
          amount: -8.25,
          accountId: checking.id,
          categoryLabel: 'Coffee / Quick Food',
          fingerprint: 'coffee',
        ),
        Transaction(
          date: DateTime(2026, 3, 5),
          description: 'Payroll',
          amount: 1500,
          accountId: checking.id,
          categoryLabel: 'Income / Payroll',
          fingerprint: 'payroll',
        ),
        Transaction(
          date: DateTime(2026, 4, 2),
          description: 'Unknown purchase',
          amount: -12,
          accountId: card.id,
          categoryLabel: kUnknownCategoryName,
          fingerprint: 'unknown',
        ),
      ];
      final resolved = resolveTransactions(
        transactions,
        categoryOverrides: const {},
        categoryDisplayRenamesLower: const {},
        accountsById: {checking.id: checking, card.id: card},
        allTransactions: transactions,
      );

      final index = buildRexDrilldownIndex(
        resolvedTransactions: resolved,
        accountsById: {checking.id: checking, card.id: card},
      );

      final months = index['months'] as List<Map<String, dynamic>>;
      expect(months.first['key'], '2026-04');
      expect(months.first['sample_transaction_ids'], contains('unknown'));

      final accounts = index['accounts'] as List<Map<String, dynamic>>;
      expect(accounts.map((item) => item['label']), contains('Checking'));
      expect(accounts.map((item) => item['label']), contains('Visa'));

      final categories = index['categories'] as List<Map<String, dynamic>>;
      final coffee = categories.singleWhere(
        (item) => item['label'] == 'Coffee / Quick Food',
      );
      expect(coffee['spend'], 8.25);

      final reviewQueues = index['review_queues'] as List<Map<String, dynamic>>;
      final needsCategory = reviewQueues.singleWhere(
        (item) => item['key'] == 'needsCategory',
      );
      expect(needsCategory['transaction_count'], 1);
      expect(needsCategory['sample_transaction_ids'], contains('unknown'));
    },
  );
}

TransactionRecord _record({
  required String id,
  required DateTime date,
  required String categoryId,
}) {
  return TransactionRecord(
    id: id,
    userId: 'user',
    accountId: 'checking',
    categoryId: categoryId,
    amount: -10,
    type: 'expense',
    description: 'Transaction $id',
    date: date,
    merchant: null,
    importedFromCsv: true,
    importId: 'import',
    createdAt: date,
    updatedAt: date,
  );
}
