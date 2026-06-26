import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../accounts/data/account_service.dart';
import '../../accounts/data/account_statement_import_service.dart';
import '../../categories/data/category_service.dart';
import '../application/transaction_record_mapper.dart';
import '../domain/transaction_fingerprint.dart';
import 'csv_import_categorizer.dart';
import 'csv_import_helpers.dart';
import 'csv_import_models.dart';
import 'csv_parser.dart';
import 'merchant_category_rule_service.dart';
import 'openai_proxy_client.dart';
import 'transaction_service.dart';

export 'csv_import_models.dart';

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
typedef _UpsertMerchantCategoryRule =
    Future<void> Function({
      required String merchantKey,
      String? merchantDisplay,
      required String categoryId,
    });

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
         upsertMerchantCategoryRule: ({
           required merchantKey,
           merchantDisplay,
           required categoryId,
         }) async {
           await merchantCategoryRuleService.upsertRule(
             merchantKey: merchantKey,
             merchantDisplay: merchantDisplay,
             categoryId: categoryId,
           );
         },
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
    _UpsertMerchantCategoryRule? upsertMerchantCategoryRule,
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
         upsertMerchantCategoryRule:
             upsertMerchantCategoryRule ??
             ({
               required String merchantKey,
               String? merchantDisplay,
               required String categoryId,
             }) async {},
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
    required _UpsertMerchantCategoryRule upsertMerchantCategoryRule,
  }) : _fetchAccounts = fetchAccounts,
       _fetchTransactions = fetchTransactions,
       _createTransactions = createTransactions,
       _upsertStatementImport = upsertStatementImport,
       _categorizer = CsvImportCategorizer(
         fetchCategories: fetchCategories,
         fetchMerchantCategoryRules: fetchMerchantCategoryRules,
         createCategory: createCategory,
         updateTransactionsCategory: updateTransactionsCategory,
         isAiConfigured: isAiConfigured,
         categorizeTransactions: categorizeTransactions,
         upsertMerchantCategoryRule: upsertMerchantCategoryRule,
       );

  final _FetchAccounts _fetchAccounts;
  final _FetchTransactions _fetchTransactions;
  final _CreateTransactions _createTransactions;
  final _UpsertStatementImport _upsertStatementImport;
  final CsvImportCategorizer _categorizer;

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
      final stamped = stampTransactionForAccount(transaction, id);
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
      final spendReference = importSpendReference(parsed.transactions);

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
      final fallbackCategoryId = await _categorizer.ensureFallbackCategoryId();

      final rowsToInsert = <TransactionCreateInput>[];
      var skippedDuplicateCount = 0;
      for (final transaction in parsed.transactions) {
        final stamped = stampTransactionForAccount(transaction, id);
        final fingerprint = transactionFingerprint(stamped);
        if (existingFingerprints.contains(fingerprint)) {
          skippedDuplicateCount += 1;
          continue;
        }
        existingFingerprints.add(fingerprint);
        rowsToInsert.add(
          TransactionCreateInput(
            accountId: id,
            categoryId: fallbackCategoryId,
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
      final dateRange = transactionDateRange(parsed.transactions);
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
      var miscellaneousCategoryCount = 0;
      var aiCategorizedCount = 0;
      var learnedRuleCategorizedCount = 0;
      var deterministicFallbackCategorizedCount = 0;
      var categoryUpdateFailureCount = 0;
      var suggestedCategoryByTransactionId = <String, String>{};

      if (insertedRecords.isNotEmpty) {
        final ruleCategoryByTransactionId = await _categorizer
            .learnedCategoryNamesFor(insertedRecords);
        learnedRuleCategorizedCount = _categorizer.resolvedSuggestionCount(
          ruleCategoryByTransactionId,
        );
        final recordsNeedingAi = insertedRecords
            .where(
              (record) => !ruleCategoryByTransactionId.containsKey(record.id),
            )
            .toList(growable: false);
        final allowedCategoryNames = recordsNeedingAi.isEmpty
            ? const <String>[]
            : await _categorizer.allowedCategoryNamesForAi();

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
          final batches = chunkList(
            recordsNeedingAi,
            kCsvCategorizationRequestBatchSize,
          );
          var nextBatchIndex = 0;
          var completed = 0;
          final active = <int, Future<CsvImportCategorizationBatchResult>>{};

          void startNextBatch() {
            if (nextBatchIndex >= batches.length) return;
            final index = nextBatchIndex;
            nextBatchIndex += 1;
            active[index] = _categorizer.categorizeBatchWithFallback(
              index,
              batches[index],
              allowedCategoryNames,
            );
          }

          while (active.length < kCsvMaxConcurrentCategorizationRequests &&
              nextBatchIndex < batches.length) {
            startNextBatch();
          }

          while (active.isNotEmpty) {
            final result = await Future.any(active.values);
            active.remove(result.index);
            suggestions.addAll(result.suggestions);
            if (result.error != null) {
              aiErrors.add(result.error!);
              deterministicFallbackCategorizedCount += _categorizer
                  .resolvedSuggestionCount(result.suggestions);
            } else {
              aiCategorizedCount += _categorizer.resolvedSuggestionCount(
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
          final applied = await _categorizer.applyCategories(
            insertedRecords,
            suggestedCategoryByTransactionId,
          );
          miscellaneousCategoryCount = applied.miscellaneousCategoryCount;
        } on Object catch (error) {
          aiErrorMessage ??= '$error';
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
        miscellaneousCategoryCount: miscellaneousCategoryCount,
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
        remainingUncategorizedCount: 0,
      );
    }

    final uncategorizedCategoryIds =
        await _categorizer.legacyUncategorizedCategoryIds();
    final repairable = batch
        .where((record) {
          final categoryId = record.categoryId?.trim();
          return categoryId == null ||
              categoryId.isEmpty ||
              uncategorizedCategoryIds.contains(categoryId);
        })
        .toList(growable: false);
    if (repairable.isEmpty) {
      return CsvImportRepairResult(
        accountId: id,
        importId: batchId,
        scannedCount: batch.length,
        repairableCount: 0,
        updatedCount: 0,
        remainingUncategorizedCount: 0,
      );
    }

    final suggestions = await _categorizer.suggestCategoriesForRecords(
      repairable,
    );
    final applied = await _categorizer.applyCategories(repairable, suggestions);
    return CsvImportRepairResult(
      accountId: id,
      importId: batchId,
      scannedCount: batch.length,
      repairableCount: repairable.length,
      updatedCount: applied.updatedTransactionCount,
      remainingUncategorizedCount: 0,
    );
  }
}
