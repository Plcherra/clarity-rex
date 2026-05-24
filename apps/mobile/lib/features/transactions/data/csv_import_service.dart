import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../accounts/data/account_service.dart';
import '../../accounts/data/account_statement_import_service.dart';
import '../../categories/data/category_service.dart';
import '../../categories/domain/category_normalization.dart';
import '../application/transaction_record_mapper.dart';
import '../domain/merchant_normalization.dart';
import '../domain/spend_categories.dart';
import '../domain/transaction_fingerprint.dart';
import 'csv_parser.dart';
import 'merchant_category_rule_service.dart';
import 'openai_proxy_client.dart';
import 'transaction_service.dart';

const int _categorizationRequestBatchSize = 100;
const int _maxConcurrentCategorizationRequests = 3;

typedef _FetchAccounts = Future<List<Account>> Function();
typedef _FetchTransactions =
    Future<List<TransactionRecord>> Function({String? accountId});
typedef _CreateTransactions =
    Future<List<TransactionRecord>> Function(
      List<TransactionCreateInput> transactions,
    );
typedef _FetchCategories = Future<List<CategoryRecord>> Function();
typedef _FetchMerchantCategoryRules =
    Future<List<MerchantCategoryRule>> Function();
typedef _CreateCategory =
    Future<CategoryRecord> Function({
      required String name,
      required String type,
      String? color,
      String? icon,
    });
typedef _UpdateTransactionsCategory =
    Future<void> Function({
      required List<String> ids,
      required String categoryId,
    });
typedef _CategorizeTransactions =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> body);
typedef _UpsertStatementImport =
    Future<void> Function(AccountStatementImportInput input);

enum CsvImportStage {
  parsing,
  savingTransactions,
  categorizingWithAi,
  applyingCategories,
  refreshing,
  complete,
  failed,
}

class CsvImportBatchSummary {
  const CsvImportBatchSummary({
    required this.importId,
    required this.transactionCount,
    required this.importedAtUtc,
  });

  final String importId;
  final int transactionCount;
  final DateTime? importedAtUtc;
}

class CsvImportResult {
  const CsvImportResult({
    required this.accountId,
    required this.importId,
    required this.parsedCount,
    required this.insertedCount,
    required this.skippedDuplicateCount,
    required this.categorizedCount,
    required this.fallbackCategoryCount,
    required this.aiSucceeded,
    required this.aiErrorMessage,
    required this.spendReference,
    required this.diagnostics,
    this.statementBalance,
    this.statementStartDate,
    this.statementEndDate,
    this.aiCategorizedCount = 0,
    this.learnedRuleCategorizedCount = 0,
    this.deterministicFallbackCategorizedCount = 0,
    this.categoryUpdateFailureCount = 0,
  });

  final String accountId;
  final String importId;
  final int parsedCount;
  final int insertedCount;
  final int skippedDuplicateCount;
  final int categorizedCount;
  final int fallbackCategoryCount;
  final bool aiSucceeded;
  final String? aiErrorMessage;
  final DateTime spendReference;
  final CsvParseDiagnostics? diagnostics;
  final double? statementBalance;
  final DateTime? statementStartDate;
  final DateTime? statementEndDate;
  final int aiCategorizedCount;
  final int learnedRuleCategorizedCount;
  final int deterministicFallbackCategorizedCount;
  final int categoryUpdateFailureCount;
}

class CsvImportRepairResult {
  const CsvImportRepairResult({
    required this.accountId,
    required this.importId,
    required this.scannedCount,
    required this.repairableCount,
    required this.updatedCount,
    required this.remainingReviewCount,
  });

  final String accountId;
  final String importId;
  final int scannedCount;
  final int repairableCount;
  final int updatedCount;
  final int remainingReviewCount;
}

class CsvImportPreview {
  const CsvImportPreview({
    required this.accountId,
    required this.parsedCount,
    required this.newTransactionCount,
    required this.duplicateCount,
    required this.incomeCount,
    required this.spendingCount,
    required this.startDate,
    required this.endDate,
    required this.endingBalance,
    required this.diagnostics,
  });

  final String accountId;
  final int parsedCount;
  final int newTransactionCount;
  final int duplicateCount;
  final int incomeCount;
  final int spendingCount;
  final DateTime startDate;
  final DateTime endDate;
  final double? endingBalance;
  final CsvParseDiagnostics? diagnostics;

  bool get hasNewTransactions => newTransactionCount > 0;
}

class CsvImportProgress {
  const CsvImportProgress({
    required this.stage,
    required this.value,
    required this.message,
    this.result,
    this.error,
  });

  factory CsvImportProgress.complete(CsvImportResult result) =>
      CsvImportProgress(
        stage: CsvImportStage.complete,
        value: 1,
        message: result.categoryUpdateFailureCount > 0
            ? 'Imported with category assignment errors.'
            : result.fallbackCategoryCount > 0
            ? 'Imported transactions; some still need automatic categories.'
            : 'Import complete.',
        result: result,
      );

  factory CsvImportProgress.failed(Object error) => CsvImportProgress(
    stage: CsvImportStage.failed,
    value: 1,
    message: 'Could not import this CSV: $error',
    error: error,
  );

  final CsvImportStage stage;
  final double value;
  final String message;
  final CsvImportResult? result;
  final Object? error;
}

class CsvImportService {
  CsvImportService({
    required AccountService accountService,
    required TransactionService transactionService,
    required CategoryService categoryService,
    required MerchantCategoryRuleService merchantCategoryRuleService,
    required AccountStatementImportService accountStatementImportService,
    required OpenAiProxyClient openAiClient,
  }) : this._(
         fetchAccounts: accountService.fetchAccounts,
         fetchTransactions: transactionService.fetchTransactions,
         createTransactions: transactionService.createTransactions,
         fetchCategories: categoryService.fetchCategories,
         fetchMerchantCategoryRules: merchantCategoryRuleService.fetchRules,
         upsertStatementImport: (input) async {
           await accountStatementImportService.upsertImport(input);
         },
         createCategory: categoryService.createCategory,
         updateTransactionsCategory:
             transactionService.updateTransactionsCategory,
         isAiConfigured: () => openAiClient.isConfigured,
         categorizeTransactions: openAiClient.categorizeTransactions,
       );

  @visibleForTesting
  CsvImportService.test({
    required Future<List<Account>> Function() fetchAccounts,
    required Future<List<TransactionRecord>> Function({String? accountId})
    fetchTransactions,
    required Future<List<TransactionRecord>> Function(
      List<TransactionCreateInput> transactions,
    )
    createTransactions,
    required Future<List<CategoryRecord>> Function() fetchCategories,
    required Future<List<MerchantCategoryRule>> Function()
    fetchMerchantCategoryRules,
    Future<void> Function(AccountStatementImportInput input)?
    upsertStatementImport,
    required Future<CategoryRecord> Function({
      required String name,
      required String type,
      String? color,
      String? icon,
    })
    createCategory,
    required Future<void> Function({
      required List<String> ids,
      required String categoryId,
    })
    updateTransactionsCategory,
    required bool Function() isAiConfigured,
    required Future<Map<String, dynamic>> Function(Map<String, dynamic> body)
    categorizeTransactions,
  }) : this._(
         fetchAccounts: fetchAccounts,
         fetchTransactions: fetchTransactions,
         createTransactions: createTransactions,
         fetchCategories: fetchCategories,
         fetchMerchantCategoryRules: fetchMerchantCategoryRules,
         upsertStatementImport: upsertStatementImport ?? (_) async {},
         createCategory: createCategory,
         updateTransactionsCategory: updateTransactionsCategory,
         isAiConfigured: isAiConfigured,
         categorizeTransactions: categorizeTransactions,
       );

  CsvImportService._({
    required _FetchAccounts fetchAccounts,
    required _FetchTransactions fetchTransactions,
    required _CreateTransactions createTransactions,
    required _FetchCategories fetchCategories,
    required _FetchMerchantCategoryRules fetchMerchantCategoryRules,
    required _UpsertStatementImport upsertStatementImport,
    required _CreateCategory createCategory,
    required _UpdateTransactionsCategory updateTransactionsCategory,
    required bool Function() isAiConfigured,
    required _CategorizeTransactions categorizeTransactions,
  }) : _fetchAccounts = fetchAccounts,
       _fetchTransactions = fetchTransactions,
       _createTransactions = createTransactions,
       _fetchCategories = fetchCategories,
       _fetchMerchantCategoryRules = fetchMerchantCategoryRules,
       _upsertStatementImport = upsertStatementImport,
       _createCategory = createCategory,
       _updateTransactionsCategory = updateTransactionsCategory,
       _isAiConfigured = isAiConfigured,
       _categorizeTransactions = categorizeTransactions;

  final _FetchAccounts _fetchAccounts;
  final _FetchTransactions _fetchTransactions;
  final _CreateTransactions _createTransactions;
  final _FetchCategories _fetchCategories;
  final _FetchMerchantCategoryRules _fetchMerchantCategoryRules;
  final _UpsertStatementImport _upsertStatementImport;
  final _CreateCategory _createCategory;
  final _UpdateTransactionsCategory _updateTransactionsCategory;
  final bool Function() _isAiConfigured;
  final _CategorizeTransactions _categorizeTransactions;

  Future<CsvImportPreview> previewImport(
    String utf8Text, {
    required String accountId,
  }) async {
    final id = accountId.trim();
    if (id.isEmpty) {
      throw const FormatException('An account must be selected.');
    }

    final parsed = parseBankCsv(utf8Text);
    final accounts = await _fetchAccounts();
    if (!accounts.any((account) => account.id == id)) {
      throw const FormatException('Unknown account.');
    }

    final existingRecords = await _fetchTransactions(accountId: id);
    final existingFingerprints = {
      for (final record in existingRecords)
        transactionFingerprint(transactionFromRecord(record)),
    };

    var duplicateCount = 0;
    var incomeCount = 0;
    var spendingCount = 0;
    var startDate = parsed.transactions.first.date;
    var endDate = parsed.transactions.first.date;
    for (final transaction in parsed.transactions) {
      if (transaction.date.isBefore(startDate)) startDate = transaction.date;
      if (transaction.date.isAfter(endDate)) endDate = transaction.date;
      if (transaction.amount >= 0) {
        incomeCount += 1;
      } else {
        spendingCount += 1;
      }
      final stamped = _stampTransactionForAccount(transaction, id);
      final fingerprint = transactionFingerprint(stamped);
      if (existingFingerprints.contains(fingerprint)) {
        duplicateCount += 1;
        continue;
      }
      existingFingerprints.add(fingerprint);
    }

    return CsvImportPreview(
      accountId: id,
      parsedCount: parsed.transactions.length,
      newTransactionCount: parsed.transactions.length - duplicateCount,
      duplicateCount: duplicateCount,
      incomeCount: incomeCount,
      spendingCount: spendingCount,
      startDate: startDate,
      endDate: endDate,
      endingBalance: parsed.totalBalance,
      diagnostics: parsed.diagnostics,
    );
  }

  Stream<CsvImportProgress> importAndCategorize(
    File csvFile, {
    required String accountId,
    Future<void> Function(CsvImportResult result)? refreshAfterImport,
  }) async* {
    final id = accountId.trim();
    try {
      if (id.isEmpty) {
        throw const FormatException('An account must be selected.');
      }

      yield const CsvImportProgress(
        stage: CsvImportStage.parsing,
        value: 0.02,
        message: 'Reading CSV...',
      );
      final utf8Text = utf8.decode(
        await csvFile.readAsBytes(),
        allowMalformed: true,
      );
      final parsed = parseBankCsv(utf8Text);

      final accounts = await _fetchAccounts();
      if (!accounts.any((account) => account.id == id)) {
        throw const FormatException('Unknown account.');
      }

      final importId = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
      final spendReference = _importSpendReference(parsed.transactions);

      yield CsvImportProgress(
        stage: CsvImportStage.savingTransactions,
        value: 0.12,
        message: 'Checking existing transactions...',
      );
      final existingRecords = await _fetchTransactions(accountId: id);
      final existingFingerprints = {
        for (final record in existingRecords)
          transactionFingerprint(transactionFromRecord(record)),
      };
      final unknownCategoryId = await _ensureUnknownCategoryId();

      final rowsToInsert = <TransactionCreateInput>[];
      var skippedDuplicateCount = 0;
      for (final transaction in parsed.transactions) {
        final stamped = _stampTransactionForAccount(transaction, id);
        final fingerprint = transactionFingerprint(stamped);
        if (existingFingerprints.contains(fingerprint)) {
          skippedDuplicateCount += 1;
          continue;
        }
        existingFingerprints.add(fingerprint);
        rowsToInsert.add(
          TransactionCreateInput(
            accountId: id,
            categoryId: unknownCategoryId,
            amount: stamped.amount.abs(),
            type: stamped.amount < 0 ? 'expense' : 'income',
            description: stamped.description,
            date: stamped.date,
            merchant: stamped.description,
            importedFromCsv: true,
            importId: importId,
          ),
        );
      }

      yield CsvImportProgress(
        stage: CsvImportStage.savingTransactions,
        value: 0.28,
        message: 'Saving transactions...',
      );
      final insertedRecords = await _createTransactions(rowsToInsert);
      final dateRange = _transactionDateRange(parsed.transactions);
      if (insertedRecords.isNotEmpty) {
        await _upsertStatementImport(
          AccountStatementImportInput(
            accountId: id,
            importId: importId,
            statementBalance: parsed.totalBalance,
            startDate: dateRange?.start,
            endDate: dateRange?.end,
            transactionCount: insertedRecords.length,
          ),
        );
      }

      var aiSucceeded = true;
      String? aiErrorMessage;
      var fallbackCategoryCount = 0;
      var aiCategorizedCount = 0;
      var learnedRuleCategorizedCount = 0;
      var deterministicFallbackCategorizedCount = 0;
      var categoryUpdateFailureCount = 0;
      var suggestedCategoryByTransactionId = <String, String>{};

      if (insertedRecords.isNotEmpty) {
        final ruleCategoryByTransactionId = await _learnedCategoryNamesFor(
          insertedRecords,
        );
        learnedRuleCategorizedCount = _resolvedSuggestionCount(
          ruleCategoryByTransactionId,
        );
        final recordsNeedingAi = insertedRecords
            .where(
              (record) => !ruleCategoryByTransactionId.containsKey(record.id),
            )
            .toList(growable: false);
        final allowedCategoryNames = recordsNeedingAi.isEmpty
            ? const <String>[]
            : await _allowedCategoryNamesForAi();

        yield CsvImportProgress(
          stage: CsvImportStage.categorizingWithAi,
          value: 0.55,
          message: recordsNeedingAi.isEmpty
              ? 'Applying learned categories...'
              : 'Categorizing with AI...',
        );
        final suggestions = <String, String>{};
        final aiErrors = <Object>[];
        if (recordsNeedingAi.isNotEmpty) {
          final batches = _chunks(
            recordsNeedingAi,
            _categorizationRequestBatchSize,
          );
          var nextBatchIndex = 0;
          var completed = 0;
          final active = <int, Future<_CategorizationBatchResult>>{};

          void startNextBatch() {
            if (nextBatchIndex >= batches.length) return;
            final index = nextBatchIndex;
            nextBatchIndex += 1;
            active[index] = _categorizeBatchWithFallback(
              index,
              batches[index],
              allowedCategoryNames,
            );
          }

          while (active.length < _maxConcurrentCategorizationRequests &&
              nextBatchIndex < batches.length) {
            startNextBatch();
          }

          while (active.isNotEmpty) {
            final result = await Future.any(active.values);
            active.remove(result.index);
            suggestions.addAll(result.suggestions);
            if (result.error != null) {
              aiErrors.add(result.error!);
              deterministicFallbackCategorizedCount += _resolvedSuggestionCount(
                result.suggestions,
              );
            } else {
              aiCategorizedCount += _resolvedSuggestionCount(
                result.suggestions,
              );
            }
            completed += 1;
            yield CsvImportProgress(
              stage: CsvImportStage.categorizingWithAi,
              value: 0.55 + (completed / batches.length) * 0.25,
              message:
                  'Categorizing with AI... $completed/${batches.length} batches',
            );
            startNextBatch();
          }
        }
        suggestions.addAll(ruleCategoryByTransactionId);
        suggestedCategoryByTransactionId = suggestions;
        if (aiErrors.isNotEmpty) {
          aiSucceeded = false;
          aiErrorMessage = '${aiErrors.first}';
        }

        yield CsvImportProgress(
          stage: CsvImportStage.applyingCategories,
          value: 0.82,
          message: aiSucceeded
              ? 'Applying categories...'
              : 'AI failed. Applying fallback categories...',
        );
        try {
          final applied = await _applyCategories(
            insertedRecords,
            suggestedCategoryByTransactionId,
          );
          fallbackCategoryCount = applied.fallbackCategoryCount;
        } on Object catch (error) {
          aiErrorMessage ??= '$error';
          fallbackCategoryCount = insertedRecords.length;
          categoryUpdateFailureCount = insertedRecords.length;
        }
      }

      final result = CsvImportResult(
        accountId: id,
        importId: importId,
        parsedCount: parsed.transactions.length,
        insertedCount: insertedRecords.length,
        skippedDuplicateCount: skippedDuplicateCount,
        categorizedCount: insertedRecords.length,
        fallbackCategoryCount: fallbackCategoryCount,
        aiSucceeded: aiSucceeded,
        aiErrorMessage: aiErrorMessage,
        spendReference: spendReference,
        diagnostics: parsed.diagnostics,
        statementBalance: parsed.totalBalance,
        statementStartDate: dateRange?.start,
        statementEndDate: dateRange?.end,
        aiCategorizedCount: aiCategorizedCount,
        learnedRuleCategorizedCount: learnedRuleCategorizedCount,
        deterministicFallbackCategorizedCount:
            deterministicFallbackCategorizedCount,
        categoryUpdateFailureCount: categoryUpdateFailureCount,
      );
      if (refreshAfterImport != null) {
        yield const CsvImportProgress(
          stage: CsvImportStage.refreshing,
          value: 0.96,
          message: 'Refreshing dashboard...',
        );
        await refreshAfterImport(result);
      }
      yield CsvImportProgress.complete(result);
    } on Object catch (error) {
      yield CsvImportProgress.failed(error);
      rethrow;
    }
  }

  Future<CsvImportRepairResult> repairImportCategories({
    required String accountId,
    required String importId,
  }) async {
    final id = accountId.trim();
    final batchId = importId.trim();
    if (id.isEmpty || batchId.isEmpty) {
      throw const FormatException('An import batch must be selected.');
    }

    final records = await _fetchTransactions(accountId: id);
    final batch = records
        .where((record) => record.importId?.trim() == batchId)
        .toList(growable: false);
    if (batch.isEmpty) {
      return CsvImportRepairResult(
        accountId: id,
        importId: batchId,
        scannedCount: 0,
        repairableCount: 0,
        updatedCount: 0,
        remainingReviewCount: 0,
      );
    }

    final unknownCategoryId = await _ensureUnknownCategoryId();
    final repairable = batch
        .where((record) {
          final categoryId = record.categoryId?.trim();
          return categoryId == null ||
              categoryId.isEmpty ||
              categoryId == unknownCategoryId;
        })
        .toList(growable: false);
    if (repairable.isEmpty) {
      return CsvImportRepairResult(
        accountId: id,
        importId: batchId,
        scannedCount: batch.length,
        repairableCount: 0,
        updatedCount: 0,
        remainingReviewCount: 0,
      );
    }

    final suggestions = await _suggestCategoriesForRecords(repairable);
    final applied = await _applyCategories(repairable, suggestions);
    return CsvImportRepairResult(
      accountId: id,
      importId: batchId,
      scannedCount: batch.length,
      repairableCount: repairable.length,
      updatedCount: applied.updatedTransactionCount,
      remainingReviewCount: applied.fallbackCategoryCount,
    );
  }

  Future<Map<String, String>> _suggestCategoriesForRecords(
    List<TransactionRecord> records,
  ) async {
    if (records.isEmpty) return const {};
    final suggestions = <String, String>{};
    final learned = await _learnedCategoryNamesFor(records);
    suggestions.addAll(learned);
    final recordsNeedingAi = records
        .where((record) => !learned.containsKey(record.id))
        .toList(growable: false);
    if (recordsNeedingAi.isEmpty) return suggestions;
    final allowedCategoryNames = await _allowedCategoryNamesForAi();
    final batches = _chunks(recordsNeedingAi, _categorizationRequestBatchSize);
    for (var i = 0; i < batches.length; i += 1) {
      final result = await _categorizeBatchWithFallback(
        i,
        batches[i],
        allowedCategoryNames,
      );
      suggestions.addAll(result.suggestions);
    }
    return suggestions;
  }

  Future<Map<String, String>> _categorizeInsertedRows(
    List<TransactionRecord> records,
    List<String> allowedCategories,
  ) async {
    if (!_isAiConfigured()) {
      throw const OpenAiProxyUnavailableException();
    }
    final response = await _categorizeTransactions({
      'allowedCategories': allowedCategories,
      'transactions': [
        for (final record in records)
          {
            'key': record.id,
            'date': record.date.toIso8601String().split('T').first,
            'amount': signedTransactionAmountFromRecord(record),
            'description': record.description ?? record.merchant ?? '',
          },
      ],
    });
    final suggestions = _parseCategorizationResponse(response);
    final errors = response['errors'];
    if (errors is List && errors.isNotEmpty) {
      if (suggestions.isEmpty) {
        throw FormatException('AI categorization failed: ${errors.first}');
      }
      debugPrint(
        '[Clarity][CSV import] AI returned partial fallback warnings: '
        '${errors.first}',
      );
    }
    return suggestions;
  }

  Future<_CategorizationBatchResult> _categorizeBatchWithFallback(
    int index,
    List<TransactionRecord> records,
    List<String> allowedCategories,
  ) async {
    try {
      return _CategorizationBatchResult(
        index: index,
        suggestions: await _categorizeInsertedRows(records, allowedCategories),
      );
    } on Object catch (error) {
      return _CategorizationBatchResult(
        index: index,
        suggestions: _fallbackCategoriesForRecords(records),
        error: error,
      );
    }
  }

  Map<String, String> _parseCategorizationResponse(
    Map<String, dynamic> response,
  ) {
    final rawSuggestions = response['suggestions'];
    if (rawSuggestions is! List) {
      throw const FormatException(
        'AI categorization response missing suggestions.',
      );
    }
    final out = <String, String>{};
    final duplicateKeys = <String>{};
    for (final suggestion in rawSuggestions) {
      if (suggestion is! Map) continue;
      final key = suggestion['key'];
      final categoryName = suggestion['categoryName'];
      if (key is! String || key.trim().isEmpty) continue;
      final cleanedKey = key.trim();
      if (out.containsKey(cleanedKey)) {
        duplicateKeys.add(cleanedKey);
        out[cleanedKey] = kUnknownCategoryName;
        continue;
      }
      if (categoryName is! String || categoryName.trim().isEmpty) {
        out[cleanedKey] = kUnknownCategoryName;
        continue;
      }
      final normalized = normalizeCategoryName(categoryName);
      out[cleanedKey] = normalized?.displayName ?? kUnknownCategoryName;
    }
    for (final key in duplicateKeys) {
      out[key] = kUnknownCategoryName;
    }
    return out;
  }

  Map<String, String> _fallbackCategoriesForRecords(
    List<TransactionRecord> records,
  ) {
    return {
      for (final record in records)
        record.id: _fallbackCategoryForRecord(record),
    };
  }

  String _fallbackCategoryForRecord(TransactionRecord record) {
    final description = record.description ?? record.merchant ?? '';
    final suggested = suggestCategoryFromDescription(
      description,
      amount: record.amount,
    );
    if (suggested.trim().toLowerCase() == 'uncategorized') {
      return kUnknownCategoryName;
    }
    return normalizeCategoryName(suggested)?.displayName ??
        kUnknownCategoryName;
  }

  Future<_CategoryApplicationResult> _applyCategories(
    List<TransactionRecord> insertedRecords,
    Map<String, String> suggestedCategoryByTransactionId,
  ) async {
    if (insertedRecords.isEmpty) {
      return const _CategoryApplicationResult(
        fallbackCategoryCount: 0,
        updatedTransactionCount: 0,
      );
    }
    final categoryNames = <String>{kUnknownCategoryName};
    for (final record in insertedRecords) {
      final name = suggestedCategoryByTransactionId[record.id]?.trim();
      categoryNames.add(
        name == null || name.isEmpty ? kUnknownCategoryName : name,
      );
    }
    final categoryIdByName = await _ensureCategories(categoryNames);
    final unknownCategoryId =
        categoryIdByName[normalizedCategoryKey(kUnknownCategoryName)];
    if (unknownCategoryId == null || unknownCategoryId.trim().isEmpty) {
      throw StateError('Could not resolve the Unknown category.');
    }
    final idsByCategoryId = <String, List<String>>{};
    var fallbackCategoryCount = 0;
    for (final record in insertedRecords) {
      if (record.categoryId == null || record.categoryId!.trim().isEmpty) {
        throw StateError(
          'Inserted transaction is missing the Unknown fallback category.',
        );
      }
      final name =
          suggestedCategoryByTransactionId[record.id]?.trim() ??
          kUnknownCategoryName;
      final normalizedName = name.isEmpty ? kUnknownCategoryName : name;
      final normalizedCategory = normalizeCategoryName(normalizedName);
      final categoryId =
          categoryIdByName[normalizedCategory?.normalizedName] ??
          unknownCategoryId;
      if (categoryId == unknownCategoryId) {
        fallbackCategoryCount += 1;
      }
      if (record.categoryId == categoryId) continue;
      idsByCategoryId.putIfAbsent(categoryId, () => <String>[]).add(record.id);
    }
    for (final entry in idsByCategoryId.entries) {
      await _updateTransactionsCategory(
        ids: entry.value,
        categoryId: entry.key,
      );
    }
    return _CategoryApplicationResult(
      fallbackCategoryCount: fallbackCategoryCount,
      updatedTransactionCount: idsByCategoryId.values.fold<int>(
        0,
        (sum, ids) => sum + ids.length,
      ),
    );
  }

  int _resolvedSuggestionCount(Map<String, String> suggestions) {
    var count = 0;
    for (final categoryName in suggestions.values) {
      if (!isUnresolvedCategoryLabel(categoryName)) count += 1;
    }
    return count;
  }

  Future<List<String>> _allowedCategoryNamesForAi() async {
    final byKey = <String, String>{};

    void add(String name) {
      final normalized = normalizeCategoryName(name);
      if (normalized == null) return;
      byKey[normalized.normalizedName] = normalized.displayName;
    }

    for (final categoryName in kSelectableSpendCategories) {
      add(categoryName);
    }
    add(kUnknownCategoryName);

    final existing = await _fetchCategories();
    for (final category in existing) {
      add(category.name);
    }

    final names = byKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  Future<Map<String, String>> _ensureCategories(
    Set<String> categoryNames,
  ) async {
    final existing = await _fetchCategories();
    final out = <String, String>{};
    for (final category in existing) {
      out[categoryRecordKey(
            name: category.name,
            normalizedName: category.normalizedName,
          )] =
          category.id;
      out[normalizedCategoryKey(category.name)] = category.id;
    }
    for (final rawName in categoryNames) {
      final normalized =
          normalizeCategoryName(rawName) ??
          normalizeCategoryName(kUnknownCategoryName);
      if (normalized == null) {
        throw StateError('Could not normalize the Unknown category.');
      }
      final key = normalized.normalizedName;
      if (out.containsKey(key)) continue;
      final created = await _createCategory(
        name: normalized.displayName,
        type: isIncomeCategoryLabel(normalized.displayName)
            ? 'income'
            : 'expense',
      );
      out[key] = created.id;
    }
    return out;
  }

  Future<String> _ensureUnknownCategoryId() async {
    final categoryIdByName = await _ensureCategories({kUnknownCategoryName});
    final unknownCategoryId =
        categoryIdByName[normalizedCategoryKey(kUnknownCategoryName)];
    if (unknownCategoryId == null || unknownCategoryId.trim().isEmpty) {
      throw StateError('Could not resolve the Unknown category.');
    }
    return unknownCategoryId;
  }

  Future<Map<String, String>> _learnedCategoryNamesFor(
    List<TransactionRecord> records,
  ) async {
    final rules = await _fetchMerchantCategoryRules();
    if (rules.isEmpty || records.isEmpty) return const {};

    final categories = await _fetchCategories();
    final categoryNameById = {
      for (final category in categories) category.id: category.name,
    };
    final ruleNameByMerchantKey = <String, String>{};
    for (final rule in rules) {
      if (rule.disabled) continue;
      final categoryName = categoryNameById[rule.categoryId];
      if (categoryName == null) continue;
      final normalizedCategory = normalizeCategoryName(categoryName);
      if (normalizedCategory == null) continue;

      final keys = <String>{rule.merchantKey.trim().toLowerCase()};
      keys.addAll(rule.aliases.map((alias) => alias.trim().toLowerCase()));
      keys.removeWhere((key) => key.isEmpty);
      for (final key in keys) {
        ruleNameByMerchantKey[key] = normalizedCategory.displayName;
      }
    }
    if (ruleNameByMerchantKey.isEmpty) return const {};

    final out = <String, String>{};
    for (final record in records) {
      final merchantKey = merchantKeyLowerFromDescription(
        record.description ?? record.merchant ?? '',
      );
      if (merchantKey.isEmpty) continue;
      final categoryName = ruleNameByMerchantKey[merchantKey];
      if (categoryName == null) continue;
      out[record.id] = categoryName;
    }
    return out;
  }
}

final class _CategoryApplicationResult {
  const _CategoryApplicationResult({
    required this.fallbackCategoryCount,
    required this.updatedTransactionCount,
  });

  final int fallbackCategoryCount;
  final int updatedTransactionCount;
}

final class _CategorizationBatchResult {
  const _CategorizationBatchResult({
    required this.index,
    required this.suggestions,
    this.error,
  });

  final int index;
  final Map<String, String> suggestions;
  final Object? error;
}

List<List<T>> _chunks<T>(List<T> items, int size) {
  final out = <List<T>>[];
  for (var i = 0; i < items.length; i += size) {
    final end = i + size > items.length ? items.length : i + size;
    out.add(items.sublist(i, end));
  }
  return out;
}

Transaction _stampTransactionForAccount(
  Transaction transaction,
  String accountId,
) {
  return Transaction(
    date: transaction.date,
    description: transaction.description,
    amount: transaction.amount,
    accountId: accountId,
    category: transaction.category,
    balanceAfter: transaction.balanceAfter,
  );
}

DateTime _importSpendReference(List<Transaction> transactions) {
  if (transactions.isEmpty) return DateTime.now();
  final spendTransactions = transactions
      .where((transaction) => transaction.amount < 0)
      .toList();
  final candidates = spendTransactions.isEmpty
      ? transactions
      : spendTransactions;
  var latest = candidates.first.date;
  for (final transaction in candidates.skip(1)) {
    if (transaction.date.isAfter(latest)) {
      latest = transaction.date;
    }
  }
  return latest;
}

({DateTime start, DateTime end})? _transactionDateRange(
  List<Transaction> transactions,
) {
  if (transactions.isEmpty) return null;
  var start = transactions.first.date;
  var end = transactions.first.date;
  for (final transaction in transactions.skip(1)) {
    if (transaction.date.isBefore(start)) start = transaction.date;
    if (transaction.date.isAfter(end)) end = transaction.date;
  }
  return (start: start, end: end);
}
