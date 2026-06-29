import 'package:clarity/features/transactions/application/import_job_status_service.dart';
import 'package:clarity/features/transactions/data/csv_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

CsvImportResult _importResult({
  int insertedCount = 10,
  int skippedDuplicateCount = 0,
  int miscellaneousCategoryCount = 0,
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
    miscellaneousCategoryCount: miscellaneousCategoryCount,
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
    final service = importJobStatusServiceForTests();
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
    final service = importJobStatusServiceForTests();

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

  test('miscellaneous categories are reported as successful import', () {
    final service = importJobStatusServiceForTests();

    service.applyCsvImportProgress(
      CsvImportProgress.complete(
        _importResult(
          insertedCount: 269,
          miscellaneousCategoryCount: 4,
          aiSucceeded: false,
        ),
      ),
      notifyStatusChanged: () {},
    );

    expect(
      service.importSnackMessage,
      'Imported 269 transactions. Categorized all; 4 used a best-guess category.',
    );
    expect(service.persistentImportMessage, isNull);
    expect(service.persistentImportMessageIsError, isFalse);
    expect(service.persistentImportMessageHasFallbackCategories, isFalse);
    expect(service.persistentImportMessageCanRetry, isFalse);
  });

  test('duplicate-only import does not report a failed categorization', () {
    final service = importJobStatusServiceForTests();

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
    final service = importJobStatusServiceForTests();

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
    final service = importJobStatusServiceForTests();

    service.applyCsvImportProgress(
      CsvImportProgress.complete(
        _importResult(
          insertedCount: 10,
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

  test('category repair result reports updated rows', () {
    final service = importJobStatusServiceForTests();

    service.startImportRepair(notifyStatusChanged: () {});
    service.applyImportRepairResult(
      const CsvImportRepairResult(
        accountId: 'account-1',
        importId: 'import-1',
        scannedCount: 10,
        repairableCount: 10,
        updatedCount: 10,
        remainingUncategorizedCount: 0,
      ),
      notifyStatusChanged: () {},
    );

    expect(service.importRunning, isFalse);
    expect(
      service.importSnackMessage,
      'Retried categories. Updated 10 transactions.',
    );
    expect(service.persistentImportMessage, contains('Updated 10'));
    expect(service.persistentImportMessageCanRetry, isFalse);
    expect(service.persistentImportSummary?.title, 'Category retry complete');
  });

  test('category repair success remains visible as a repair summary', () {
    final service = importJobStatusServiceForTests();

    service.startImportRepair(notifyStatusChanged: () {});
    service.applyImportRepairResult(
      const CsvImportRepairResult(
        accountId: 'account-1',
        importId: 'import-1',
        scannedCount: 10,
        repairableCount: 10,
        updatedCount: 10,
        remainingUncategorizedCount: 0,
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
