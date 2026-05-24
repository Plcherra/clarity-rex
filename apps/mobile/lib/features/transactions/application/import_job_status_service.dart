import 'package:flutter/foundation.dart';

import '../data/csv_import_service.dart';

class ImportRepairSummary {
  const ImportRepairSummary({
    required this.title,
    required this.lines,
    required this.canReview,
    required this.canRetry,
    required this.canOpenCategoryManagement,
  });

  final String title;
  final List<String> lines;
  final bool canReview;
  final bool canRetry;
  final bool canOpenCategoryManagement;
}

class ImportJobStatusService {
  bool importRunning = false;
  int importProgressCompleted = 0;
  int importProgressTotal = 100;
  String importProgressMessage = 'Uploading transactions...';

  String? importSnackMessage;
  String? persistentImportMessage;
  bool persistentImportMessageIsError = false;
  bool persistentImportMessageHasFallbackCategories = false;
  ImportRepairSummary? persistentImportSummary;
  String? repairImportAccountId;
  String? repairImportId;

  bool get persistentImportMessageCanRetry =>
      !importRunning &&
      repairImportAccountId?.trim().isNotEmpty == true &&
      repairImportId?.trim().isNotEmpty == true;

  void applyCsvImportProgress(
    CsvImportProgress progress, {
    required VoidCallback notifyStatusChanged,
  }) {
    importProgressCompleted = (progress.value * 100).round().clamp(0, 100);
    importProgressTotal = 100;
    importProgressMessage = progress.message;

    switch (progress.stage) {
      case CsvImportStage.complete:
        importRunning = false;
        final result = progress.result;
        if (result == null) {
          importSnackMessage = 'Import complete.';
          persistentImportMessage = null;
          persistentImportMessageIsError = false;
          persistentImportMessageHasFallbackCategories = false;
          persistentImportSummary = null;
        } else if (result.categoryUpdateFailureCount > 0) {
          importSnackMessage =
              'Imported ${result.insertedCount} transactions, but category assignment failed.';
          persistentImportMessage =
              'Imported ${result.insertedCount} transactions, but ${result.categoryUpdateFailureCount} need category assignment retry.';
          persistentImportMessageIsError = true;
          persistentImportMessageHasFallbackCategories = true;
          persistentImportSummary = _summaryForImportResult(
            result,
            title: 'Import needs category retry',
            canReview: false,
            canRetry: true,
          );
          repairImportAccountId = result.accountId;
          repairImportId = result.importId;
        } else if (result.insertedCount == 0) {
          importSnackMessage = result.skippedDuplicateCount > 0
              ? 'No new transactions imported. ${result.skippedDuplicateCount} duplicates skipped.'
              : 'No new transactions imported.';
          persistentImportMessage = null;
          persistentImportMessageIsError = false;
          persistentImportMessageHasFallbackCategories = false;
          persistentImportSummary = null;
          repairImportAccountId = null;
          repairImportId = null;
        } else if (result.fallbackCategoryCount > 0) {
          importSnackMessage =
              'Imported ${result.insertedCount} transactions. Retrying ${result.fallbackCategoryCount} uncategorized rows is available.';
          persistentImportMessage =
              'Imported ${result.insertedCount} transactions. ${result.fallbackCategoryCount} still need automatic categories.';
          persistentImportMessageIsError = false;
          persistentImportMessageHasFallbackCategories = true;
          persistentImportSummary = _summaryForImportResult(
            result,
            title: 'Import needs category retry',
            canReview: false,
            canRetry: true,
          );
          repairImportAccountId = result.accountId;
          repairImportId = result.importId;
        } else {
          final localCategoryCount =
              result.learnedRuleCategorizedCount +
              result.deterministicFallbackCategorizedCount;
          importSnackMessage = localCategoryCount > 0
              ? 'Imported ${result.insertedCount} transactions. Categorized all; $localCategoryCount used local rules.'
              : 'Imported ${result.insertedCount} transactions. Categorized all transactions.';
          persistentImportMessage = null;
          persistentImportMessageIsError = false;
          persistentImportMessageHasFallbackCategories = false;
          persistentImportSummary = null;
          repairImportAccountId = null;
          repairImportId = null;
        }
      case CsvImportStage.failed:
        importRunning = false;
        importSnackMessage = progress.message;
        persistentImportMessage = progress.message;
        persistentImportMessageIsError = true;
        persistentImportMessageHasFallbackCategories = false;
        persistentImportSummary = ImportRepairSummary(
          title: 'Import failed',
          lines: [progress.message],
          canReview: false,
          canRetry: false,
          canOpenCategoryManagement: false,
        );
        repairImportAccountId = null;
        repairImportId = null;
      case CsvImportStage.parsing:
      case CsvImportStage.savingTransactions:
      case CsvImportStage.categorizingWithAi:
      case CsvImportStage.applyingCategories:
      case CsvImportStage.refreshing:
        importRunning = true;
        importSnackMessage = null;
        persistentImportMessage = null;
        persistentImportMessageIsError = false;
        persistentImportMessageHasFallbackCategories = false;
        persistentImportSummary = null;
        repairImportAccountId = null;
        repairImportId = null;
    }

    notifyStatusChanged();
  }

  void startImportRepair({required VoidCallback notifyStatusChanged}) {
    importRunning = true;
    importProgressCompleted = 0;
    importProgressTotal = 100;
    importProgressMessage = 'Retrying category assignment...';
    importSnackMessage = null;
    persistentImportMessage = null;
    persistentImportMessageIsError = false;
    persistentImportMessageHasFallbackCategories = false;
    persistentImportSummary = null;
    notifyStatusChanged();
  }

  void applyImportRepairResult(
    CsvImportRepairResult result, {
    required VoidCallback notifyStatusChanged,
  }) {
    importRunning = false;
    importProgressCompleted = 100;
    importProgressTotal = 100;
    importProgressMessage = 'Category retry complete.';
    if (result.repairableCount == 0) {
      importSnackMessage = 'No retryable category rows found.';
      persistentImportMessage = 'No retryable category rows found.';
      persistentImportMessageIsError = false;
      persistentImportMessageHasFallbackCategories = false;
      persistentImportSummary = _summaryForRepairResult(
        result,
        title: 'No retryable rows',
        canReview: false,
        canRetry: false,
      );
      repairImportAccountId = null;
      repairImportId = null;
    } else if (result.remainingReviewCount > 0) {
      importSnackMessage =
          'Retried categories. ${result.remainingReviewCount} remain uncategorized.';
      persistentImportMessage =
          'Retried categories. ${result.remainingReviewCount} transactions still need automatic categories.';
      persistentImportMessageIsError = false;
      persistentImportMessageHasFallbackCategories = true;
      persistentImportSummary = _summaryForRepairResult(
        result,
        title: 'Category retry complete',
        canReview: false,
        canRetry: true,
      );
      repairImportAccountId = result.accountId;
      repairImportId = result.importId;
    } else {
      importSnackMessage =
          'Retried categories. Updated ${result.updatedCount} transactions.';
      persistentImportMessage =
          'Retried categories. Updated ${result.updatedCount} transactions.';
      persistentImportMessageIsError = false;
      persistentImportMessageHasFallbackCategories = false;
      persistentImportSummary = _summaryForRepairResult(
        result,
        title: 'Category retry complete',
        canReview: false,
        canRetry: false,
      );
      repairImportAccountId = null;
      repairImportId = null;
    }
    notifyStatusChanged();
  }

  void applyImportRepairFailure(
    Object error, {
    required VoidCallback notifyStatusChanged,
  }) {
    importRunning = false;
    importProgressCompleted = 100;
    importProgressTotal = 100;
    importProgressMessage = 'Category retry failed.';
    importSnackMessage = 'Could not retry category assignment: $error';
    persistentImportMessage = importSnackMessage;
    persistentImportMessageIsError = true;
    persistentImportMessageHasFallbackCategories = true;
    persistentImportSummary = ImportRepairSummary(
      title: 'Category retry failed',
      lines: ['Retry failed: $error'],
      canReview: false,
      canRetry: persistentImportMessageCanRetry,
      canOpenCategoryManagement: true,
    );
    notifyStatusChanged();
  }

  String? consumeImportSnackMessage() {
    final message = importSnackMessage;
    importSnackMessage = null;
    return message;
  }

  void dismissPersistentImportMessage({
    required VoidCallback notifyStatusChanged,
  }) {
    persistentImportMessage = null;
    persistentImportMessageIsError = false;
    persistentImportMessageHasFallbackCategories = false;
    persistentImportSummary = null;
    repairImportAccountId = null;
    repairImportId = null;
    notifyStatusChanged();
  }

  void clear({required VoidCallback notifyStatusChanged}) {
    importRunning = false;
    importProgressCompleted = 0;
    importProgressTotal = 100;
    importProgressMessage = 'Uploading transactions...';
    importSnackMessage = null;
    persistentImportMessage = null;
    persistentImportMessageIsError = false;
    persistentImportMessageHasFallbackCategories = false;
    persistentImportSummary = null;
    repairImportAccountId = null;
    repairImportId = null;
    notifyStatusChanged();
  }

  ImportRepairSummary _summaryForImportResult(
    CsvImportResult result, {
    required String title,
    required bool canReview,
    required bool canRetry,
  }) {
    final localCount =
        result.learnedRuleCategorizedCount +
        result.deterministicFallbackCategorizedCount;
    return ImportRepairSummary(
      title: title,
      lines: [
        'Parsed ${result.parsedCount}; imported ${result.insertedCount}; skipped ${result.skippedDuplicateCount} duplicates.',
        'AI ${result.aiSucceeded ? 'completed' : 'unavailable'}; AI rows ${result.aiCategorizedCount}; local-rule rows $localCount.',
        'Uncategorized ${result.fallbackCategoryCount}; category update failures ${result.categoryUpdateFailureCount}.',
      ],
      canReview: canReview,
      canRetry: canRetry,
      canOpenCategoryManagement:
          result.fallbackCategoryCount > 0 ||
          result.categoryUpdateFailureCount > 0,
    );
  }

  ImportRepairSummary _summaryForRepairResult(
    CsvImportRepairResult result, {
    required String title,
    required bool canReview,
    required bool canRetry,
  }) {
    return ImportRepairSummary(
      title: title,
      lines: [
        'Scanned ${result.scannedCount}; retryable ${result.repairableCount}.',
        'Updated ${result.updatedCount}; still uncategorized ${result.remainingReviewCount}.',
      ],
      canReview: canReview,
      canRetry: canRetry,
      canOpenCategoryManagement: result.remainingReviewCount > 0,
    );
  }
}
