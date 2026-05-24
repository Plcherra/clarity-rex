import 'dart:io';

import 'package:clarity/core/models/models.dart';
import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/features/accounts/data/account_statement_import_service.dart';
import 'package:clarity/features/categories/domain/category_normalization.dart';
import 'package:clarity/features/transactions/data/csv_import_service.dart';
import 'package:clarity/features/transactions/data/merchant_category_rule_service.dart';
import 'package:clarity/features/transactions/data/transaction_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'large CSV inserts all rows and applies AI categories in bulk',
    () async {
      final harness = _CsvImportHarness();
      final file = await _writeCsv(_csvRows(1505));

      final events = await harness.service
          .importAndCategorize(file, accountId: _accountId)
          .toList();

      expect(events.first.stage, CsvImportStage.parsing);
      final result = events.last.result;
      expect(result, isNotNull);
      expect(result!.parsedCount, 1505);
      expect(result.insertedCount, 1505);
      expect(result.skippedDuplicateCount, 0);
      expect(result.categorizedCount, 1505);
      expect(result.fallbackCategoryCount, 0);
      expect(result.aiSucceeded, isTrue);
      expect(harness.createdInputs, hasLength(1505));
      expect(
        harness.createdInputs.every(
          (transaction) => transaction.categoryId == 'cat-unknown',
        ),
        isTrue,
      );
      expect(harness.categoryUpdates, hasLength(1));
      expect(harness.categoryUpdates.single.categoryId, 'cat-food');
      expect(harness.categoryUpdates.single.ids, hasLength(1505));
      expect(harness.statementImports, hasLength(1));
      expect(harness.statementImports.single.statementBalance, 3496);
      expect(harness.statementImports.single.transactionCount, 1505);
    },
  );

  test(
    'large Unknown fallback applies every inserted row in one grouped request',
    () async {
      final harness = _CsvImportHarness(aiConfigured: false);
      final file = await _writeCsv(_csvRows(1549));

      final events = await harness.service
          .importAndCategorize(file, accountId: _accountId)
          .toList();

      final result = events.last.result;
      expect(result, isNotNull);
      expect(result!.insertedCount, 1549);
      expect(result.aiSucceeded, isFalse);
      expect(result.fallbackCategoryCount, 1549);
      expect(
        harness.createdInputs.every(
          (transaction) => transaction.categoryId == 'cat-unknown',
        ),
        isTrue,
      );
      expect(harness.categoryUpdates, isEmpty);
    },
  );

  test(
    'dedupe checks all existing transactions when account has 1000+ rows',
    () async {
      final duplicate = _transactionRecord(
        id: 'existing-duplicate',
        amount: 1.25,
        date: DateTime(2025),
        description: 'Merchant 0',
        type: 'expense',
      );
      final existing = <TransactionRecord>[
        duplicate,
        for (var i = 0; i < 1000; i += 1)
          _transactionRecord(
            id: 'existing-$i',
            amount: (i % 90) + 10.25,
            date: DateTime(2023, 1, 1).add(Duration(days: i)),
            description: 'Existing Merchant $i',
            type: 'expense',
          ),
      ];
      final harness = _CsvImportHarness(
        existingTransactions: existing,
        aiConfigured: false,
      );
      final file = await _writeCsv(_csvRows(1501));

      final events = await harness.service
          .importAndCategorize(file, accountId: _accountId)
          .toList();

      final result = events.last.result;
      expect(result, isNotNull);
      expect(result!.parsedCount, 1501);
      expect(result.insertedCount, 1500);
      expect(result.skippedDuplicateCount, 1);
      expect(result.aiSucceeded, isFalse);
      expect(result.fallbackCategoryCount, 1500);
      expect(harness.createdInputs, hasLength(1500));
      expect(
        harness.createdInputs.every(
          (transaction) => transaction.categoryId == 'cat-unknown',
        ),
        isTrue,
      );
      expect(harness.categoryUpdates, isEmpty);
    },
  );

  test('preview reports date range duplicates and ending balance', () async {
    final harness = _CsvImportHarness(
      existingTransactions: [
        _transactionRecord(
          id: 'existing-duplicate',
          amount: 1.25,
          date: DateTime(2025),
          description: 'Merchant 0',
          type: 'expense',
        ),
      ],
    );

    final preview = await harness.service.previewImport(
      _csvRows(3),
      accountId: _accountId,
    );

    expect(preview.parsedCount, 3);
    expect(preview.duplicateCount, 1);
    expect(preview.newTransactionCount, 2);
    expect(preview.spendingCount, 3);
    expect(preview.incomeCount, 0);
    expect(_dateOnly(preview.startDate), '2025-01-01');
    expect(_dateOnly(preview.endDate), '2025-01-03');
    expect(preview.endingBalance, 4998);
    expect(preview.hasNewTransactions, isTrue);
  });

  test(
    'repair import categories retries Unknown rows for one import',
    () async {
      final harness = _CsvImportHarness(
        existingTransactions: [
          _transactionRecord(
            id: 'retry-1',
            amount: 12,
            date: DateTime(2026, 3, 1),
            description: 'TST* BOM DOUGH',
            type: 'expense',
            importId: 'import-retry',
            categoryId: 'cat-unknown',
          ),
          _transactionRecord(
            id: 'retry-2',
            amount: 30,
            date: DateTime(2026, 3, 2),
            description: 'PAYROLL DEPOSIT',
            type: 'income',
            importId: 'import-retry',
            categoryId: 'cat-unknown',
          ),
          _transactionRecord(
            id: 'other-import',
            amount: 7,
            date: DateTime(2026, 3, 3),
            description: 'OTHER IMPORT',
            type: 'expense',
            importId: 'other-import',
            categoryId: 'cat-unknown',
          ),
        ],
        categorizeTransactions: (body) async {
          final transactions = body['transactions'] as List;
          return {
            'suggestions': [
              for (final transaction in transactions.cast<Map>())
                {
                  'key': transaction['key'],
                  'categoryName': transaction['key'] == 'retry-2'
                      ? 'Income / Payroll'
                      : 'Coffee / Quick Food',
                },
            ],
          };
        },
      );

      final result = await harness.service.repairImportCategories(
        accountId: _accountId,
        importId: 'import-retry',
      );

      expect(result.scannedCount, 2);
      expect(result.repairableCount, 2);
      expect(result.updatedCount, 2);
      expect(result.remainingReviewCount, 0);
      expect(harness.createdCategoryTypes['Income / Payroll'], 'income');
      expect(
        harness.categoryUpdates.map((update) => update.categoryId).toSet(),
        {'cat-coffee', 'cat-income-payroll'},
      );
      expect(harness.categoryUpdates.expand((update) => update.ids).toSet(), {
        'retry-1',
        'retry-2',
      });
    },
  );

  test('duplicate-only import does not persist statement metadata', () async {
    final existing = _transactionRecord(
      id: 'existing-duplicate',
      amount: 1.25,
      date: DateTime(2025),
      description: 'Merchant 0',
      type: 'expense',
    );
    final harness = _CsvImportHarness(existingTransactions: [existing]);
    final file = await _writeCsv(_csvRows(1));

    final events = await harness.service
        .importAndCategorize(file, accountId: _accountId)
        .toList();

    final result = events.last.result;
    expect(result, isNotNull);
    expect(result!.insertedCount, 0);
    expect(result.skippedDuplicateCount, 1);
    expect(harness.statementImports, isEmpty);
  });

  test(
    'AI failure completes import and applies local fallback categories',
    () async {
      final harness = _CsvImportHarness(
        categorizeTransactions: (_) async {
          throw const FormatException('AI unavailable');
        },
      );
      final file = await _writeCsv(
        'Date,Description,Amount,Balance\n'
        '2026-03-01,CVS/PHARMACY #123,-12.36,1000.00\n'
        '2026-03-02,DSW DOWNTOWN C,-59.99,940.01\n'
        '2026-03-03,UNKNOWN MERCHANT,-3.25,936.76\n',
      );

      final events = await harness.service
          .importAndCategorize(file, accountId: _accountId)
          .toList();

      final result = events.last.result;
      expect(result, isNotNull);
      expect(result!.insertedCount, 3);
      expect(result.aiSucceeded, isFalse);
      expect(result.aiErrorMessage, contains('AI unavailable'));
      expect(result.fallbackCategoryCount, 1);
      expect(result.aiCategorizedCount, 0);
      expect(result.learnedRuleCategorizedCount, 0);
      expect(result.deterministicFallbackCategorizedCount, 2);
      expect(result.categoryUpdateFailureCount, 0);
      expect(
        harness.createdInputs.every(
          (transaction) => transaction.categoryId == 'cat-unknown',
        ),
        isTrue,
      );
      final updatesByCategory = {
        for (final update in harness.categoryUpdates)
          update.categoryId: update.ids,
      };
      expect(updatesByCategory['cat-pharmacy-health'], ['txn-0']);
      expect(updatesByCategory['cat-shoes-clothing'], ['txn-1']);
    },
  );

  test('import spend reference uses latest expense date', () async {
    final harness = _CsvImportHarness(aiConfigured: false);
    final file = await _writeCsv(
      'Date,Description,Amount,Balance\n'
      '2026-05-04,APPLE.COM/BILL REFUND,4.95,1004.95\n'
      '2026-04-20,DUNKIN #123,-5.25,999.70\n',
    );

    final events = await harness.service
        .importAndCategorize(file, accountId: _accountId)
        .toList();

    final result = events.last.result;
    expect(result, isNotNull);
    expect(result!.spendReference.year, 2026);
    expect(result.spendReference.month, 4);
    expect(result.spendReference.day, 20);
  });

  test('import stream owns refresh stage before completion', () async {
    final harness = _CsvImportHarness();
    final file = await _writeCsv(_csvRows(2));
    var refreshed = false;

    final events = await harness.service
        .importAndCategorize(
          file,
          accountId: _accountId,
          refreshAfterImport: (_) async {
            refreshed = true;
          },
        )
        .toList();

    expect(refreshed, isTrue);
    expect(events.map((event) => event.stage), [
      CsvImportStage.parsing,
      CsvImportStage.savingTransactions,
      CsvImportStage.savingTransactions,
      CsvImportStage.categorizingWithAi,
      CsvImportStage.categorizingWithAi,
      CsvImportStage.applyingCategories,
      CsvImportStage.refreshing,
      CsvImportStage.complete,
    ]);
  });

  test('large imports call AI in 100-row requests', () async {
    final harness = _CsvImportHarness();
    final file = await _writeCsv(_csvRows(250));

    final events = await harness.service
        .importAndCategorize(file, accountId: _accountId)
        .toList();

    final categorizingEvents = events
        .where((event) => event.stage == CsvImportStage.categorizingWithAi)
        .toList();
    expect(harness.categorizeRequestSizes, [100, 100, 50]);
    expect(categorizingEvents.last.message, contains('3/3 batches'));
    expect(categorizingEvents.last.value, closeTo(0.80, 0.001));
  });

  test(
    'missing invalid duplicate AI suggestions fall back to Unknown',
    () async {
      final harness = _CsvImportHarness(
        categorizeTransactions: (_) async => {
          'suggestions': [
            {'key': 'txn-0', 'categoryName': 'Food & Drink'},
            {'key': 'txn-1', 'categoryName': 'C'},
            {'key': 'txn-2', 'categoryName': 'https://not-safe.example'},
            {'key': 'txn-3', 'categoryName': 'Shopping'},
            {'key': 'txn-3', 'categoryName': 'Food & Drink'},
          ],
        },
      );
      final file = await _writeCsv(_csvRows(4));

      final events = await harness.service
          .importAndCategorize(file, accountId: _accountId)
          .toList();

      final result = events.last.result;
      expect(result, isNotNull);
      expect(result!.aiSucceeded, isTrue);
      expect(result.fallbackCategoryCount, 3);
      expect(result.aiCategorizedCount, 1);
      expect(harness.categoryUpdates, hasLength(1));

      final idsByCategoryId = {
        for (final update in harness.categoryUpdates)
          update.categoryId: update.ids,
      };
      expect(idsByCategoryId['cat-food'], ['txn-0']);
      expect(
        harness.createdInputs.every(
          (transaction) => transaction.categoryId == 'cat-unknown',
        ),
        isTrue,
      );
    },
  );

  test('AI-created category is normalized, created, and assigned', () async {
    final harness = _CsvImportHarness(
      categorizeTransactions: (_) async => {
        'suggestions': [
          {'key': 'txn-0', 'categoryName': ' pet-care!! '},
          {'key': 'txn-1', 'categoryName': 'PET care'},
        ],
      },
    );
    final file = await _writeCsv(_csvRows(2));

    final events = await harness.service
        .importAndCategorize(file, accountId: _accountId)
        .toList();

    final result = events.last.result;
    expect(result, isNotNull);
    expect(result!.aiSucceeded, isTrue);
    expect(result.fallbackCategoryCount, 0);
    expect(harness.createdCategoryNames, ['Pet Care']);
    expect(harness.categoryUpdates, hasLength(1));
    expect(harness.categoryUpdates.single.categoryId, 'cat-pet-care');
    expect(harness.categoryUpdates.single.ids, ['txn-0', 'txn-1']);
  });

  test('learned merchant rules apply during import before AI', () async {
    final harness = _CsvImportHarness(
      merchantRules: const [
        MerchantCategoryRule(
          id: 'rule-dunkin',
          userId: _userId,
          merchantKey: 'dunkin',
          aliases: [],
          categoryId: 'cat-coffee',
          matchType: 'normalized_exact',
          confidence: 1,
        ),
      ],
    );
    final file = await _writeCsv(
      'Date,Description,Amount,Balance\n'
      '2026-03-01,DUNKIN #304654 12/31 MOBILE PURCHASE SOMERVILLE MA,-5.25,1000.00\n'
      '2026-03-02,DD/BR #1234,-4.75,995.25\n',
    );

    final events = await harness.service
        .importAndCategorize(file, accountId: _accountId)
        .toList();

    final result = events.last.result;
    expect(result, isNotNull);
    expect(result!.insertedCount, 2);
    expect(result.aiSucceeded, isTrue);
    expect(result.fallbackCategoryCount, 0);
    expect(result.learnedRuleCategorizedCount, 2);
    expect(result.aiCategorizedCount, 0);
    expect(result.deterministicFallbackCategorizedCount, 0);
    expect(harness.categorizeRequestSizes, isEmpty);
    expect(harness.categoryUpdates, hasLength(1));
    expect(harness.categoryUpdates.single.categoryId, 'cat-coffee');
    expect(harness.categoryUpdates.single.ids, ['txn-0', 'txn-1']);
  });

  test('disabled merchant rules do not apply during import', () async {
    final harness = _CsvImportHarness(
      merchantRules: const [
        MerchantCategoryRule(
          id: 'rule-dunkin',
          userId: _userId,
          merchantKey: 'dunkin',
          aliases: [],
          categoryId: 'cat-coffee',
          matchType: 'normalized_exact',
          confidence: 1,
          disabled: true,
        ),
      ],
    );
    final file = await _writeCsv(
      'Date,Description,Amount,Balance\n'
      '2026-03-01,DUNKIN #304654 12/31 MOBILE PURCHASE SOMERVILLE MA,-5.25,1000.00\n',
    );

    final events = await harness.service
        .importAndCategorize(file, accountId: _accountId)
        .toList();

    final result = events.last.result;
    expect(result, isNotNull);
    expect(result!.learnedRuleCategorizedCount, 0);
    expect(result.aiCategorizedCount, 1);
    expect(harness.categorizeRequestSizes, [1]);
    expect(harness.categoryUpdates.single.categoryId, 'cat-food');
  });

  test(
    'learned merchant rules reduce AI request size for mixed imports',
    () async {
      final harness = _CsvImportHarness(
        merchantRules: const [
          MerchantCategoryRule(
            id: 'rule-dunkin',
            userId: _userId,
            merchantKey: 'dunkin',
            aliases: [],
            categoryId: 'cat-coffee',
            matchType: 'normalized_exact',
            confidence: 1,
          ),
        ],
      );
      final file = await _writeCsv(
        'Date,Description,Amount,Balance\n'
        '2026-03-01,DUNKIN #304654 12/31 MOBILE PURCHASE SOMERVILLE MA,-5.25,1000.00\n'
        '2026-03-02,MERCHANT NEEDS AI,-12.00,988.00\n',
      );

      final events = await harness.service
          .importAndCategorize(file, accountId: _accountId)
          .toList();

      final result = events.last.result;
      expect(result, isNotNull);
      expect(result!.insertedCount, 2);
      expect(result.aiSucceeded, isTrue);
      expect(harness.categorizeRequestSizes, [1]);
      final updatesByCategory = {
        for (final update in harness.categoryUpdates)
          update.categoryId: update.ids,
      };
      expect(updatesByCategory['cat-coffee'], ['txn-0']);
      expect(updatesByCategory['cat-food'], ['txn-1']);
    },
  );

  test('category improvement failure keeps inserted rows as Unknown', () async {
    final harness = _CsvImportHarness(
      updateTransactionsCategory: ({required ids, required categoryId}) async {
        throw const FormatException('bulk update failed');
      },
    );
    final file = await _writeCsv(_csvRows(2));

    final events = await harness.service
        .importAndCategorize(file, accountId: _accountId)
        .toList();

    final result = events.last.result;
    expect(result, isNotNull);
    expect(result!.insertedCount, 2);
    expect(result.aiSucceeded, isFalse);
    expect(result.aiErrorMessage, contains('bulk update failed'));
    expect(result.fallbackCategoryCount, 2);
    expect(result.categoryUpdateFailureCount, 2);
    expect(
      harness.createdInputs.every(
        (transaction) => transaction.categoryId == 'cat-unknown',
      ),
      isTrue,
    );
  });
}

const _accountId = 'account-1';
const _userId = 'user-1';

class _CsvImportHarness {
  _CsvImportHarness({
    List<TransactionRecord> existingTransactions = const [],
    bool aiConfigured = true,
    Future<Map<String, dynamic>> Function(Map<String, dynamic> body)?
    categorizeTransactions,
    Future<void> Function({
      required List<String> ids,
      required String categoryId,
    })?
    updateTransactionsCategory,
    List<MerchantCategoryRule> merchantRules = const [],
  }) : _existingTransactions = existingTransactions,
       _aiConfigured = aiConfigured,
       _categorizeTransactions = categorizeTransactions,
       _updateTransactionsCategoryOverride = updateTransactionsCategory,
       _merchantRules = merchantRules {
    service = CsvImportService.test(
      fetchAccounts: () async => const [
        Account(id: _accountId, name: 'Checking', type: AccountType.checking),
      ],
      fetchTransactions: ({String? accountId}) async => _existingTransactions,
      createTransactions: _createTransactions,
      fetchCategories: () async => _categories.values.toList(),
      fetchMerchantCategoryRules: () async => _merchantRules,
      upsertStatementImport: (input) async => statementImports.add(input),
      createCategory: _createCategory,
      updateTransactionsCategory: _updateTransactionsCategory,
      isAiConfigured: () => _aiConfigured,
      categorizeTransactions: _categorize,
    );
  }

  final List<TransactionRecord> _existingTransactions;
  final bool _aiConfigured;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> body)?
  _categorizeTransactions;
  final Future<void> Function({
    required List<String> ids,
    required String categoryId,
  })?
  _updateTransactionsCategoryOverride;
  final List<MerchantCategoryRule> _merchantRules;
  final createdInputs = <TransactionCreateInput>[];
  final statementImports = <AccountStatementImportInput>[];
  final categoryUpdates = <_CategoryUpdate>[];
  final createdCategoryNames = <String>[];
  final createdCategoryTypes = <String, String>{};
  final categorizeRequestSizes = <int>[];
  final _categories = <String, CategoryRecord>{
    'coffee / quick food': _categoryRecord(
      id: 'cat-coffee',
      name: 'Coffee / Quick Food',
    ),
    'food & drink': _categoryRecord(id: 'cat-food', name: 'Food & Drink'),
    'unknown': _categoryRecord(id: 'cat-unknown', name: kUnknownCategoryName),
  };

  late final CsvImportService service;

  Future<List<TransactionRecord>> _createTransactions(
    List<TransactionCreateInput> inputs,
  ) async {
    createdInputs.addAll(inputs);
    return [
      for (var i = 0; i < inputs.length; i += 1)
        _transactionRecord(
          id: 'txn-$i',
          categoryId: inputs[i].categoryId,
          amount: inputs[i].amount,
          date: inputs[i].date,
          description: inputs[i].description ?? '',
          type: inputs[i].type,
          importId: inputs[i].importId,
        ),
    ];
  }

  Future<CategoryRecord> _createCategory({
    required String name,
    required String type,
    String? color,
    String? icon,
  }) async {
    createdCategoryNames.add(name);
    createdCategoryTypes[name] = type;
    final record = _categoryRecord(
      id: 'cat-${normalizedCategoryKey(name).replaceAll(' ', '-')}',
      name: name,
      type: type,
    );
    _categories[normalizedCategoryKey(name)] = record;
    return record;
  }

  Future<void> _updateTransactionsCategory({
    required List<String> ids,
    required String categoryId,
  }) async {
    final override = _updateTransactionsCategoryOverride;
    if (override != null) {
      await override(ids: ids, categoryId: categoryId);
      return;
    }
    categoryUpdates.add(_CategoryUpdate(ids: ids, categoryId: categoryId));
  }

  Future<Map<String, dynamic>> _categorize(Map<String, dynamic> body) async {
    final transactions = body['transactions'];
    categorizeRequestSizes.add(transactions is List ? transactions.length : 0);
    final override = _categorizeTransactions;
    if (override != null) return override(body);
    return {
      'suggestions': [
        if (transactions is List)
          for (final transaction in transactions)
            if (transaction is Map)
              {'key': transaction['key'], 'categoryName': 'Food & Drink'},
      ],
    };
  }
}

class _CategoryUpdate {
  const _CategoryUpdate({required this.ids, required this.categoryId});

  final List<String> ids;
  final String categoryId;
}

String _csvRows(int count) {
  final rows = StringBuffer('Date,Description,Amount,Balance\n');
  final start = DateTime(2025);
  for (var i = 0; i < count; i += 1) {
    final date = start.add(Duration(days: i));
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    rows.writeln(
      '$yyyy-$mm-$dd,Merchant $i,-${(i % 90) + 1}.25,${5000 - i}.00',
    );
  }
  return rows.toString();
}

Future<File> _writeCsv(String csv) async {
  final file = File(
    '${Directory.systemTemp.path}/clarity_csv_import_test_${DateTime.now().microsecondsSinceEpoch}.csv',
  );
  addTearDown(() async {
    if (await file.exists()) await file.delete();
  });
  return file.writeAsString(csv);
}

String _dateOnly(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

TransactionRecord _transactionRecord({
  required String id,
  required double amount,
  required DateTime date,
  required String description,
  required String type,
  String? importId,
  String? categoryId,
}) {
  final now = DateTime.utc(2026);
  return TransactionRecord(
    id: id,
    userId: _userId,
    accountId: _accountId,
    categoryId: categoryId,
    amount: amount,
    type: type,
    description: description,
    date: date,
    merchant: description,
    importedFromCsv: importId != null,
    importId: importId,
    createdAt: now,
    updatedAt: now,
  );
}

CategoryRecord _categoryRecord({
  required String id,
  required String name,
  String type = 'expense',
}) {
  final now = DateTime.utc(2026);
  return CategoryRecord(
    id: id,
    userId: _userId,
    name: name,
    normalizedName: normalizedCategoryKey(name),
    type: type,
    createdAt: now,
    updatedAt: now,
  );
}
