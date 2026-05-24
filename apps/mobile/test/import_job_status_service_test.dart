import 'package:clarity/features/transactions/application/import_job_status_service.dart';
import 'package:clarity/features/transactions/data/csv_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

CsvImportResult _importResult({
  int insertedCount = 10,
  int skippedDuplicateCount = 0,
  int fallbackCategoryCount = 0,
  int deterministicFallbackCategorizedCount = 0,
  int categoryUpdateFailureCount = 0,
  bool aiSucceeded = true,
}) {
  return CsvImportResult(
    accountId: 'account-1',
    importId: 'import-1',
    parsedCount: insertedCount + skippedDuplicateCount,
    insertedCount: insertedCount,
    skippedDuplicateCount: skippedDuplicateCount,
    categorizedCount: insertedCount,
    fallbackCategoryCount: fallbackCategoryCount,
    aiSucceeded: aiSucceeded,
    aiErrorMessage: aiSucceeded ? null : 'AI unavailable',
    spendReference: DateTime(2026, 5),
    diagnostics: null,
    deterministicFallbackCategorizedCount:
        deterministicFallbackCategorizedCount,
    categoryUpdateFailureCount: categoryUpdateFailureCount,
  );
}

void main() {
  test('failed import progress remains visible until dismissed', () {
    final service = ImportJobStatusService();
    var notifications = 0;

    service.applyCsvImportProgress(
      CsvImportProgress.failed(const FormatException('Bad CSV')),
      notifyStatusChanged: () => notifications += 1,
    );

    expect(service.importRunning, isFalse);
    expect(service.importSnackMessage, contains('Could not import this CSV'));
    expect(
      service.persistentImportMessage,
      contains('Could not import this CSV'),
    );
    expect(service.persistentImportMessageIsError, isTrue);

    service.dismissPersistentImportMessage(
      notifyStatusChanged: () => notifications += 1,
    );

    expect(service.persistentImportMessage, isNull);
    expect(service.persistentImportMessageIsError, isFalse);
    expect(notifications, 2);
  });

  test('AI outage with fully categorized fallback is reported as success', () {
    final service = ImportJobStatusService();

    service.applyCsvImportProgress(
      CsvImportProgress.complete(
        _importResult(insertedCount: 269, aiSucceeded: false),
      ),
      notifyStatusChanged: () {},
    );

    expect(
      service.importSnackMessage,
      'Imported 269 transactions. Categorized all transactions.',
    );
    expect(service.persistentImportMessage, isNull);
    expect(service.persistentImportMessageIsError, isFalse);
    expect(service.persistentImportMessageHasFallbackCategories, isFalse);
  });

  test('unknown category rows are review state, not import failure', () {
    final service = ImportJobStatusService();

    service.applyCsvImportProgress(
      CsvImportProgress.complete(
        _importResult(
          insertedCount: 269,
          fallbackCategoryCount: 4,
          aiSucceeded: false,
        ),
      ),
      notifyStatusChanged: () {},
    );

    expect(
      service.importSnackMessage,
      'Imported 269 transactions. 4 need category review.',
    );
    expect(
      service.persistentImportMessage,
      'Imported 269 transactions. 4 still need category review.',
    );
    expect(service.persistentImportMessageIsError, isFalse);
    expect(service.persistentImportMessageHasFallbackCategories, isTrue);
    expect(service.persistentImportMessageCanRetry, isTrue);
    expect(service.persistentImportSummary?.title, 'Import needs review');
    expect(
      service.persistentImportSummary?.lines.join(' '),
      contains('Needs review 4'),
    );
  });

  test('duplicate-only import does not report a failed categorization', () {
    final service = ImportJobStatusService();

    service.applyCsvImportProgress(
      CsvImportProgress.complete(
        _importResult(insertedCount: 0, skippedDuplicateCount: 12),
      ),
      notifyStatusChanged: () {},
    );

    expect(
      service.importSnackMessage,
      'No new transactions imported. 12 duplicates skipped.',
    );
    expect(service.persistentImportMessage, isNull);
    expect(service.persistentImportMessageIsError, isFalse);
    expect(service.persistentImportMessageHasFallbackCategories, isFalse);
  });

  test('local category rules are reported separately from unresolved rows', () {
    final service = ImportJobStatusService();

    service.applyCsvImportProgress(
      CsvImportProgress.complete(
        _importResult(
          insertedCount: 269,
          deterministicFallbackCategorizedCount: 31,
          aiSucceeded: false,
        ),
      ),
      notifyStatusChanged: () {},
    );

    expect(
      service.importSnackMessage,
      'Imported 269 transactions. Categorized all; 31 used local rules.',
    );
    expect(service.persistentImportMessage, isNull);
    expect(service.persistentImportMessageIsError, isFalse);
  });

  test('category update failures stay visible as errors', () {
    final service = ImportJobStatusService();

    service.applyCsvImportProgress(
      CsvImportProgress.complete(
        _importResult(
          insertedCount: 10,
          fallbackCategoryCount: 10,
          categoryUpdateFailureCount: 10,
          aiSucceeded: false,
        ),
      ),
      notifyStatusChanged: () {},
    );

    expect(
      service.importSnackMessage,
      'Imported 10 transactions, but category assignment failed.',
    );
    expect(
      service.persistentImportMessage,
      'Imported 10 transactions, but 10 need category assignment retry.',
    );
    expect(service.persistentImportMessageIsError, isTrue);
    expect(service.persistentImportMessageCanRetry, isTrue);
    expect(
      service.persistentImportSummary?.title,
      'Import needs category retry',
    );
    expect(service.repairImportAccountId, 'account-1');
    expect(service.repairImportId, 'import-1');
  });

  test('category repair result reports resolved and remaining rows', () {
    final service = ImportJobStatusService();

    service.startImportRepair(notifyStatusChanged: () {});
    service.applyImportRepairResult(
      const CsvImportRepairResult(
        accountId: 'account-1',
        importId: 'import-1',
        scannedCount: 10,
        repairableCount: 10,
        updatedCount: 6,
        remainingReviewCount: 4,
      ),
      notifyStatusChanged: () {},
    );

    expect(service.importRunning, isFalse);
    expect(
      service.importSnackMessage,
      'Retried categories. 4 still need review.',
    );
    expect(service.persistentImportMessage, contains('4 transactions'));
    expect(service.persistentImportMessageCanRetry, isTrue);
    expect(service.persistentImportSummary?.title, 'Category retry complete');
    expect(
      service.persistentImportSummary?.lines.join(' '),
      contains('Updated 6; still unknown 4'),
    );
  });

  test('category repair success remains visible as a repair summary', () {
    final service = ImportJobStatusService();

    service.startImportRepair(notifyStatusChanged: () {});
    service.applyImportRepairResult(
      const CsvImportRepairResult(
        accountId: 'account-1',
        importId: 'import-1',
        scannedCount: 10,
        repairableCount: 10,
        updatedCount: 10,
        remainingReviewCount: 0,
      ),
      notifyStatusChanged: () {},
    );

    expect(service.importRunning, isFalse);
    expect(service.persistentImportMessage, contains('Updated 10'));
    expect(service.persistentImportMessageCanRetry, isFalse);
    expect(service.persistentImportSummary?.canReview, isFalse);
    expect(service.persistentImportSummary?.canOpenCategoryManagement, isFalse);
  });
}
