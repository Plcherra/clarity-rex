import 'package:flutter/foundation.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
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
  ImportJobStatusService({AppLocalizations Function()? l10n})
    : _l10n = l10n ?? (() => AppLocalizationsEn()),
      idleProgressMessage = (l10n ?? (() => AppLocalizationsEn()))().importUploadingTransactions,
      importProgressMessage =
          (l10n ?? (() => AppLocalizationsEn()))().importUploadingTransactions;

  AppLocalizations Function() _l10n;

  String idleProgressMessage;

  bool importRunning = false;
  int importProgressCompleted = 0;
  int importProgressTotal = 100;
  late String importProgressMessage;

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

  AppLocalizations get l10n => _l10n();

  void bindLocalizations(AppLocalizations localizations) {
    _l10n = () => localizations;
    idleProgressMessage = localizations.importUploadingTransactions;
    if (!importRunning) {
      importProgressMessage = idleProgressMessage;
    }
  }

  void configureIdleProgressMessage(String message) {
    idleProgressMessage = message;
    if (!importRunning) {
      importProgressMessage = message;
    }
  }

  void applyCsvImportProgress(
    CsvImportProgress progress, {
    required VoidCallback notifyStatusChanged,
  }) {
    final strings = l10n;
    importProgressCompleted = (progress.value * 100).round().clamp(0, 100);
    importProgressTotal = 100;
    importProgressMessage = progress.message;

    switch (progress.stage) {
      case CsvImportStage.complete:
        importRunning = false;
        final result = progress.result;
        if (result == null) {
          importSnackMessage = strings.importJobCompleteSnack;
          persistentImportMessage = null;
          persistentImportMessageIsError = false;
          persistentImportMessageHasFallbackCategories = false;
          persistentImportSummary = null;
        } else if (result.categoryUpdateFailureCount > 0) {
          importSnackMessage = strings.importJobCategoryAssignmentFailedSnack(
            result.insertedCount,
          );
          persistentImportMessage = strings.importJobCategoryRetryNeededPersistent(
            result.insertedCount,
            result.categoryUpdateFailureCount,
          );
          persistentImportMessageIsError = true;
          persistentImportMessageHasFallbackCategories = true;
          persistentImportSummary = _summaryForImportResult(
            result,
            title: strings.importJobNeedsCategoryRetryTitle,
            canReview: false,
            canRetry: true,
          );
          repairImportAccountId = result.accountId;
          repairImportId = result.importId;
        } else if (result.insertedCount == 0) {
          importSnackMessage = result.skippedDuplicateCount > 0
              ? strings.importJobNoNewTransactionsDuplicates(
                  result.skippedDuplicateCount,
                )
              : strings.importJobNoNewTransactions;
          persistentImportMessage = null;
          persistentImportMessageIsError = false;
          persistentImportMessageHasFallbackCategories = false;
          persistentImportSummary = null;
          repairImportAccountId = null;
          repairImportId = null;
        } else {
          final localCategoryCount =
              result.learnedRuleCategorizedCount +
              result.deterministicFallbackCategorizedCount;
          final miscCount = result.miscellaneousCategoryCount;
          importSnackMessage = localCategoryCount > 0
              ? miscCount > 0
                    ? strings.importJobSuccessWithLocalAndMisc(
                        result.insertedCount,
                        localCategoryCount,
                        miscCount,
                      )
                    : strings.importJobSuccessWithLocal(
                        result.insertedCount,
                        localCategoryCount,
                      )
              : miscCount > 0
              ? strings.importJobSuccessWithMisc(
                  result.insertedCount,
                  miscCount,
                )
              : strings.importJobSuccessCategorizedAll(result.insertedCount);
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
          title: strings.importJobFailedTitle,
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
    final strings = l10n;
    importRunning = true;
    importProgressCompleted = 0;
    importProgressTotal = 100;
    importProgressMessage = strings.importJobRetryingCategoryAssignment;
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
    final strings = l10n;
    importRunning = false;
    importProgressCompleted = 100;
    importProgressTotal = 100;
    importProgressMessage = strings.importJobCategoryRetryCompleteProgress;
    if (result.repairableCount == 0) {
      importSnackMessage = strings.importJobNoRetryableRowsSnack;
      persistentImportMessage = strings.importJobNoRetryableRowsSnack;
      persistentImportMessageIsError = false;
      persistentImportMessageHasFallbackCategories = false;
      persistentImportSummary = _summaryForRepairResult(
        result,
        title: strings.importJobNoRetryableRowsTitle,
        canReview: false,
        canRetry: false,
      );
      repairImportAccountId = null;
      repairImportId = null;
    } else {
      importSnackMessage = strings.importJobRetriedCategoriesSnack(
        result.updatedCount,
      );
      persistentImportMessage = strings.importJobRetriedCategoriesSnack(
        result.updatedCount,
      );
      persistentImportMessageIsError = false;
      persistentImportMessageHasFallbackCategories = false;
      persistentImportSummary = _summaryForRepairResult(
        result,
        title: strings.importJobCategoryRetryCompleteTitle,
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
    final strings = l10n;
    final errorText = '$error';
    importRunning = false;
    importProgressCompleted = 100;
    importProgressTotal = 100;
    importProgressMessage = strings.importJobCategoryRetryFailedProgress;
    importSnackMessage = strings.importJobCategoryRetryFailedSnack(errorText);
    persistentImportMessage = importSnackMessage;
    persistentImportMessageIsError = true;
    persistentImportMessageHasFallbackCategories = true;
    persistentImportSummary = ImportRepairSummary(
      title: strings.importJobCategoryRetryFailedTitle,
      lines: [strings.importJobRetryFailedLine(errorText)],
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
    importProgressMessage = idleProgressMessage;
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
    final strings = l10n;
    final localCount =
        result.learnedRuleCategorizedCount +
        result.deterministicFallbackCategorizedCount;
    return ImportRepairSummary(
      title: title,
      lines: [
        strings.importJobSummaryParsedLine(
          result.parsedCount,
          result.insertedCount,
          result.skippedDuplicateCount,
        ),
        strings.importJobSummaryAiLine(
          result.aiSucceeded
              ? strings.importJobAiStatusCompleted
              : strings.importJobAiStatusUnavailable,
          result.aiCategorizedCount,
          localCount,
        ),
        strings.importJobSummaryCategoriesLine(
          result.miscellaneousCategoryCount,
          result.categoryUpdateFailureCount,
        ),
      ],
      canReview: canReview,
      canRetry: canRetry,
      canOpenCategoryManagement: result.categoryUpdateFailureCount > 0,
    );
  }

  ImportRepairSummary _summaryForRepairResult(
    CsvImportRepairResult result, {
    required String title,
    required bool canReview,
    required bool canRetry,
  }) {
    final strings = l10n;
    return ImportRepairSummary(
      title: title,
      lines: [
        strings.importJobSummaryScannedLine(
          result.scannedCount,
          result.repairableCount,
        ),
        strings.importJobSummaryUpdatedLine(
          result.updatedCount,
          result.remainingUncategorizedCount,
        ),
      ],
      canReview: canReview,
      canRetry: canRetry,
      canOpenCategoryManagement: result.remainingUncategorizedCount > 0,
    );
  }
}
