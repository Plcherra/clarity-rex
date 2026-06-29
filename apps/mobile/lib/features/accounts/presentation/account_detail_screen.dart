import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/io/file_reader.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/models/models.dart';
import '../../../widgets/clarity_diamond_loader.dart';
import '../../../widgets/clarity_path_loader.dart';
import '../../budgets/application/budget_cleanup_service.dart';
import '../../transactions/data/csv_import_service.dart';
import '../../dashboard/domain/dashboard_snapshot.dart';
import '../../dashboard/presentation/financial_dashboard_view.dart';
import 'csv_plaid_duplicate_warning.dart';

class AccountDetailScreen extends StatefulWidget {
  const AccountDetailScreen({
    super.key,
    required this.controller,
    required this.dashboardController,
    required this.transactionController,
    required this.budgetController,
    required this.importJobStatusController,
    required this.accountId,
    this.seedAccount,
    this.promptCsvImport = false,
  });

  final AccountUiController controller;
  final DashboardUiController dashboardController;
  final TransactionUiController transactionController;
  final BudgetUiController budgetController;
  final ImportJobStatusController importJobStatusController;
  final String accountId;
  final Account? seedAccount;
  final bool promptCsvImport;

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  late final _AccountDetailDataNotifier _dataNotifier;
  var _deletingCsvUpload = false;
  var _csvImportPromptHandled = false;

  @override
  void initState() {
    super.initState();
    _dataNotifier = _AccountDetailDataNotifier();
    widget.controller.addListener(_handleControllerChanged);
    _loadData();
  }

  @override
  void didUpdateWidget(covariant AccountDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.accountId != widget.accountId) {
      _loadData();
    }
  }

  void _handleControllerChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    _dataNotifier.setLoading();
    try {
      final accounts = await widget.controller.accounts;
      if (!mounted) return;
      _dataNotifier.setData(accounts);
    } on Object catch (error) {
      if (!mounted) return;
      _dataNotifier.setError(error);
    }
  }

  String _batchLabel(AppLocalizations l10n, CsvImportBatchSummary batch) {
    final utc = batch.importedAtUtc;
    if (utc == null) return l10n.accountDetailUploadBatchLabel(batch.importId);
    final local = utc.toLocal();
    final yy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$yy-$mm-$dd $hh:$min';
  }

  Future<void> _deleteCsvUploadBatch(BuildContext context) async {
    if (_deletingCsvUpload) return;
    final l10n = context.l10n;

    final batches = await widget.controller.csvImportBatchesForAccount(
      widget.accountId,
    );
    if (!context.mounted) return;
    if (batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accountDetailNoCsvUploads)),
      );
      return;
    }

    final selected = await showDialog<CsvImportBatchSummary>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.accountDetailDeleteCsvUploadTitle),
        children: [
          for (final batch in batches)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(batch),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _batchLabel(l10n, batch),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    batch.transactionCount == 1
                        ? l10n.commonTransactionCountOne
                        : l10n.commonTransactionCount(batch.transactionCount),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null) return;
    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogL10n = ctx.l10n;
        final transactionSuffix = selected.transactionCount == 1 ? '' : 's';
        return AlertDialog(
          title: Text(dialogL10n.accountDetailConfirmDeleteCsvTitle),
          content: Text(
            dialogL10n.accountDetailDeleteCsvBody(
              selected.transactionCount,
              transactionSuffix,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(dialogL10n.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(dialogL10n.accountDetailDeleteUploadButton),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    setState(() => _deletingCsvUpload = true);
    var deleted = 0;
    Object? error;
    var progressDialogShown = false;
    if (context.mounted) {
      progressDialogShown = true;
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const _CsvUploadDeletingDialog(),
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }
    try {
      deleted = await widget.controller.deleteTransactionsForImportBatch(
        accountId: widget.accountId,
        importId: selected.importId,
      );
    } on Object catch (e) {
      error = e;
    } finally {
      if (mounted) setState(() => _deletingCsvUpload = false);
      if (progressDialogShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accountDetailCouldNotDeleteCsv)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted > 0
              ? l10n.accountDetailDeletedFromCsv(
                  deleted,
                  deleted == 1 ? '' : 's',
                )
              : l10n.accountDetailCsvAlreadyDeleted,
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, String accountName) async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.accountDetailDeleteAccountTitle),
        content: Text(l10n.accountDetailDeleteAccountContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.accountDetailDeleteAccountButton),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await widget.controller.deleteAccount(widget.accountId);
    if (!context.mounted) return;
    if (!result.deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accountDetailCouldNotDeleteAccount)),
      );
      return;
    }

    await _confirmUnusedCustomCategoryCleanup(
      context,
      result.customCategoryCandidates,
    );
    if (!context.mounted) return;

    final cleanupNote = result.deletedBudgetCount > 0
        ? l10n.accountDetailRemovedBudgets(
            result.deletedBudgetCount,
            result.deletedBudgetCount == 1 ? '' : 's',
          )
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.accountDetailAccountDeleted(accountName, cleanupNote),
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _confirmUnusedCustomCategoryCleanup(
    BuildContext context,
    List<BudgetCleanupCategoryCandidate> candidates,
  ) async {
    if (candidates.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogL10n = ctx.l10n;
        final names = candidates.map((candidate) => candidate.name).join(', ');
        final plural = candidates.length == 1
            ? dialogL10n.accountDetailCategorySingular
            : dialogL10n.accountDetailCategoriesPlural;
        return AlertDialog(
          title: Text(dialogL10n.accountDetailDeleteUnusedCategoryTitle(plural)),
          content: Text(
            candidates.length == 1
                ? dialogL10n.accountDetailDeleteUnusedCategorySingle(names)
                : dialogL10n.accountDetailDeleteUnusedCategoryMultiple(names),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(dialogL10n.accountDetailKeepCategories),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(dialogL10n.accountDetailDeleteCategories),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    for (final candidate in candidates) {
      await widget.controller.deleteUnusedCustomCategory(candidate.categoryId);
    }
  }

  Future<void> _importCsvForThisAccount(
    BuildContext context,
    Account account,
  ) async {
    try {
      if (account.isPlaidConnected) {
        final proceed = await confirmCsvImportForPlaidAccount(context, account);
        if (proceed != true) return;
        if (!context.mounted) return;
      }
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (!context.mounted) return;
      if (file == null) return;
      final text = await readPickedFileContents(file);
      if (!context.mounted) return;
      await widget.controller.loadFromCsv(text, accountId: widget.accountId);
    } on FormatException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.accountSelectionCouldNotImport)),
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _dataNotifier.dispose();
    super.dispose();
  }

  Account? _resolveAccount(List<Account>? accounts) {
    final fromFetch = accounts
        ?.where((item) => item.id == widget.accountId)
        .cast<Account?>()
        .firstWhere((item) => item != null, orElse: () => null);
    return fromFetch ?? widget.seedAccount;
  }

  void _maybePromptCsvImport(Account account) {
    if (!widget.promptCsvImport || _csvImportPromptHandled) return;
    _csvImportPromptHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_importCsvForThisAccount(context, account));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _dataNotifier,
      builder: (context, _) {
        final accounts = _dataNotifier.data;
        if (accounts == null) {
          if (_dataNotifier.error != null) {
            return Scaffold(
              body: Center(child: Text(context.l10n.accountDetailLoadError)),
            );
          }
          return Scaffold(
            body: Center(
              child: ClarityDiamondLoader(
                size: 56,
                label: context.l10n.accountDetailLoadingLabel,
              ),
            ),
          );
        }
        final account = _resolveAccount(accounts);
        if (account != null) {
          _maybePromptCsvImport(account);
        }
        final title = account?.displayName ?? context.l10n.accountDetailFallbackTitle;
        return FinancialDashboardView(
          controller: widget.dashboardController,
          transactionController: widget.transactionController,
          budgetController: widget.budgetController,
          importJobStatusController: widget.importJobStatusController,
          scope: AccountDashboardScope(widget.accountId),
          showBackButton: true,
          title: title,
          onUploadTransactions: account == null
              ? null
              : () => _importCsvForThisAccount(context, account),
          onDeleteCsvImportBatch: _deletingCsvUpload
              ? null
              : () => _deleteCsvUploadBatch(context),
          onDeleteAccount: () => _deleteAccount(context, title),
        );
      },
    );
  }
}

class _CsvUploadDeletingDialog extends StatelessWidget {
  const _CsvUploadDeletingDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ClarityInlineLoader(size: 24, strokeWidth: 2.5),
          const SizedBox(width: 20),
          Expanded(child: Text(context.l10n.accountDetailDeletingCsvProgress)),
        ],
      ),
    );
  }
}

class _AccountDetailDataNotifier extends ChangeNotifier {
  List<Account>? _data;
  Object? _error;
  var _loading = false;

  List<Account>? get data => _data;
  Object? get error => _error;
  bool get loading => _loading;

  void setLoading() {
    _loading = true;
    _error = null;
    notifyListeners();
  }

  void setData(List<Account> data) {
    _data = data;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  void setError(Object error) {
    _error = error;
    _loading = false;
    notifyListeners();
  }
}
