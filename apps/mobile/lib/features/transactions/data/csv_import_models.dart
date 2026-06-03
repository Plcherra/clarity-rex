import 'csv_parser.dart';

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
