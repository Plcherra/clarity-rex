import 'package:flutter/foundation.dart';

import '../data/csv_import_service.dart';

class ImportJobStatusService {
  bool importRunning = false;
  int importProgressCompleted = 0;
  int importProgressTotal = 100;
  String importProgressMessage = 'Uploading transactions...';

  String? importSnackMessage;
  String? persistentImportMessage;
  bool persistentImportMessageIsError = false;
  bool persistentImportMessageHasFallbackCategories = false;

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
        } else if (result.categoryUpdateFailureCount > 0) {
          importSnackMessage =
              'Imported ${result.insertedCount} transactions, but category assignment failed.';
          persistentImportMessage =
              'Imported ${result.insertedCount} transactions, but ${result.categoryUpdateFailureCount} need category assignment retry.';
          persistentImportMessageIsError = true;
          persistentImportMessageHasFallbackCategories = true;
        } else if (result.insertedCount == 0) {
          importSnackMessage = result.skippedDuplicateCount > 0
              ? 'No new transactions imported. ${result.skippedDuplicateCount} duplicates skipped.'
              : 'No new transactions imported.';
          persistentImportMessage = null;
          persistentImportMessageIsError = false;
          persistentImportMessageHasFallbackCategories = false;
        } else if (result.fallbackCategoryCount > 0) {
          importSnackMessage =
              'Imported ${result.insertedCount} transactions. ${result.fallbackCategoryCount} need category review.';
          persistentImportMessage =
              'Imported ${result.insertedCount} transactions. ${result.fallbackCategoryCount} still need category review.';
          persistentImportMessageIsError = false;
          persistentImportMessageHasFallbackCategories = true;
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
        }
      case CsvImportStage.failed:
        importRunning = false;
        importSnackMessage = progress.message;
        persistentImportMessage = progress.message;
        persistentImportMessageIsError = true;
        persistentImportMessageHasFallbackCategories = false;
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
    }

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
    notifyStatusChanged();
  }
}
