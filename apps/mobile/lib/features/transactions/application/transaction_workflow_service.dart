import 'dart:async';
import 'dart:io';

import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../dashboard/application/dashboard_spend_reference_controller.dart';
import '../../finance/data/financial_audit_service.dart';
import '../data/csv_import_service.dart';
import '../data/transaction_service.dart';
import '../domain/spend_categories.dart';
import 'import_job_status_service.dart';
import 'transaction_record_mapper.dart';

class TransactionWorkflowService {
  TransactionWorkflowService({
    required this.transactionService,
    required this.csvImportService,
    required this.spendReferenceController,
    required this.importJobStatusService,
    required this.financialAuditService,
    required this.deleteStatementImport,
    required this.refreshCategories,
    required this.categoryNameForId,
    required this.refreshAllState,
    required this.notifyTransactionDataChanged,
    required this.notifyImportJobStatusChanged,
  });

  final TransactionService transactionService;
  final CsvImportService csvImportService;
  final DashboardSpendReferenceController spendReferenceController;
  final ImportJobStatusService importJobStatusService;
  final FinancialAuditService financialAuditService;
  final Future<void> Function({
    required String accountId,
    required String importId,
  })
  deleteStatementImport;
  final Future<void> Function() refreshCategories;
  final String? Function(String? id) categoryNameForId;
  final Future<void> Function() refreshAllState;
  final void Function() notifyTransactionDataChanged;
  final void Function() notifyImportJobStatusChanged;

  Future<CsvImportPreview> previewCsvImport(
    String utf8Text, {
    required String accountId,
  }) {
    return csvImportService.previewImport(utf8Text, accountId: accountId);
  }

  Future<void> loadFromCsv(
    String utf8Text, {
    required String accountId,
    DateTime? reference,
  }) async {
    final tempFile = File(
      '${Directory.systemTemp.path}/clarity_import_${DateTime.now().toUtc().microsecondsSinceEpoch}.csv',
    );
    try {
      await tempFile.writeAsString(utf8Text);
      await for (final progress in csvImportService.importAndCategorize(
        tempFile,
        accountId: accountId,
        refreshAfterImport: (completed) async {
          await refreshCategories();
          spendReferenceController.spendReference =
              reference ?? completed.spendReference;
          await refreshAllState();
          notifyTransactionDataChanged();
        },
      )) {
        importJobStatusService.applyCsvImportProgress(
          progress,
          notifyStatusChanged: notifyImportJobStatusChanged,
        );
      }
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> retryImportCategoryAssignment({
    required String accountId,
    required String importId,
  }) async {
    importJobStatusService.startImportRepair(
      notifyStatusChanged: notifyImportJobStatusChanged,
    );
    try {
      final result = await csvImportService.repairImportCategories(
        accountId: accountId,
        importId: importId,
      );
      await refreshCategories();
      await refreshAllState();
      notifyTransactionDataChanged();
      importJobStatusService.applyImportRepairResult(
        result,
        notifyStatusChanged: notifyImportJobStatusChanged,
      );
    } on Object catch (error) {
      importJobStatusService.applyImportRepairFailure(
        error,
        notifyStatusChanged: notifyImportJobStatusChanged,
      );
    }
  }

  Future<TransactionRecord> addTransaction(Transaction transaction) {
    return _createTransactionFromModel(transaction);
  }

  Future<bool> deleteTransaction(Transaction transaction) async {
    if (transaction.isPlaid) return false;
    final record = await _findRecordForTransaction(transaction);
    if (record == null) return false;
    await transactionService.deleteTransaction(record.id);
    await refreshAllState();
    return true;
  }

  Future<bool> setFinancialRoleOverride(
    Transaction transaction,
    FinancialRole? role,
  ) async {
    final record = await _findRecordForTransaction(transaction);
    if (record == null) return false;
    await transactionService.updateTransaction(
      record.id,
      financialRole: role == null ? null : financialRoleToStorageValue(role),
      clearFinancialRole: role == null,
    );
    await _recordAuditEvent(
      FinancialAuditEventInput(
        eventType: 'transaction_role_override_updated',
        entityType: 'transaction',
        entityId: record.id,
        source: 'manual',
        previousValue: {'financial_role': record.financialRole},
        newValue: {
          'financial_role': role == null
              ? null
              : financialRoleToStorageValue(role),
        },
        metadata: {
          'account_id': record.accountId,
          'transaction_date': record.date.toIso8601String().split('T').first,
          'description': record.description,
          'amount': record.amount,
        },
      ),
    );
    await refreshAllState();
    notifyTransactionDataChanged();
    return true;
  }

  Future<int> clearTransactionsForAccount(String accountId) async {
    final records = await transactionService.fetchTransactions(
      accountId: accountId.trim(),
    );
    for (final record in records) {
      await transactionService.deleteTransaction(record.id);
    }
    await refreshAllState();
    return records.length;
  }

  Future<void> _recordAuditEvent(FinancialAuditEventInput input) async {
    try {
      await financialAuditService.recordEvent(input);
    } on Object {
      // Audit writes should not make an already-applied transaction edit fail.
    }
  }

  Future<int> deleteTransactionsForAccountInDateRange({
    required String accountId,
    required DateTime start,
    required DateTime endInclusive,
  }) async {
    final deleted = await transactionService
        .deleteTransactionsForAccountInDateRange(
          accountId: accountId,
          start: start,
          endInclusive: endInclusive,
        );
    if (deleted > 0) {
      await refreshAllState();
    }
    return deleted;
  }

  Future<int> deleteTransactionsForImportBatch({
    required String accountId,
    required String importId,
  }) async {
    final id = accountId.trim();
    final batchId = importId.trim();
    if (id.isEmpty || batchId.isEmpty) return 0;
    final deleted = await transactionService.deleteTransactionsForImportBatch(
      accountId: id,
      importId: batchId,
    );
    await deleteStatementImport(accountId: id, importId: batchId);
    if (deleted > 0) {
      await refreshAllState();
    }
    return deleted;
  }

  Future<TransactionRecord> _createTransactionFromModel(
    Transaction transaction, {
    bool importedFromCsv = false,
    String? importId,
  }) {
    return transactionService.createTransaction(
      accountId: transaction.accountId,
      categoryId: null,
      amount: transaction.amount.abs(),
      type: transaction.amount < 0 ? 'expense' : 'income',
      financialRole: transaction.financialRole == null
          ? null
          : financialRoleToStorageValue(transaction.financialRole!),
      description: transaction.description,
      date: transaction.date,
      merchant: transaction.description,
      importedFromCsv: importedFromCsv,
      importId: importId,
    );
  }

  Future<TransactionRecord?> _findRecordForTransaction(
    Transaction transaction,
  ) async {
    final records = await transactionService.fetchTransactions(
      accountId: transaction.accountId,
    );
    final targetKey = transaction.fingerprint?.trim().isNotEmpty == true
        ? transaction.fingerprint!
        : transactionCategoryKey(transaction);
    for (final record in records) {
      final current = transactionFromRecord(
        record,
        categoryNameForId: categoryNameForId,
      );
      final key = current.fingerprint?.trim().isNotEmpty == true
          ? current.fingerprint!
          : transactionCategoryKey(current);
      if (key == targetKey) return record;
    }
    return null;
  }

  Future<List<Transaction>> _fetchTransactions({String? accountId}) async {
    final records = await transactionService.fetchTransactions(
      accountId: accountId,
    );
    return records
        .map(
          (record) => transactionFromRecord(
            record,
            categoryNameForId: categoryNameForId,
          ),
        )
        .toList();
  }
}
