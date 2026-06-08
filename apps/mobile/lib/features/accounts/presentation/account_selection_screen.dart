import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/formatting/formatting.dart';
import '../../../core/models/models.dart';
import '../../transactions/data/csv_import_service.dart';
import '../../shell/presentation/import_job_progress_banner.dart';
import 'csv_plaid_duplicate_warning.dart';
import 'widgets/source_label_chip.dart';

/// Shown after the user picks a CSV; they must pick or create a manual account
/// before the fallback import runs.
class AccountSelectionScreen extends StatefulWidget {
  const AccountSelectionScreen({
    super.key,
    required this.controller,
    required this.importJobStatusController,
    required this.homeBuilder,
    required this.pendingCsvText,
  });

  final AccountUiController controller;
  final ImportJobStatusController importJobStatusController;
  final WidgetBuilder homeBuilder;
  final String pendingCsvText;

  @override
  State<AccountSelectionScreen> createState() => _AccountSelectionScreenState();
}

class _AccountSelectionScreenState extends State<AccountSelectionScreen> {
  late final _AccountSelectionDataNotifier _dataNotifier;
  String? _importingAccountId;

  @override
  void initState() {
    super.initState();
    _dataNotifier = _AccountSelectionDataNotifier();
    widget.controller.addListener(_handleControllerChanged);
    _loadData();
  }

  @override
  void didUpdateWidget(covariant AccountSelectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _loadData();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _dataNotifier.dispose();
    super.dispose();
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

  Future<void> _showAddAccountDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddAccountDialog(
        onCreate: (name, type, balance) async {
          final account = Account(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: name,
            type: type,
            currentBalance: balance,
          );
          final ok = await widget.controller.addAccount(account);
          if (!dialogContext.mounted) return;
          if (!ok) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(content: Text('Could not save account.')),
            );
            return;
          }
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  Future<void> _importForAccount(BuildContext context, Account account) async {
    if (_importingAccountId != null) return;
    if (account.isPlaidConnected) {
      final proceed = await confirmCsvImportForPlaidAccount(context, account);
      if (proceed != true) return;
      if (!context.mounted) return;
    }
    setState(() => _importingAccountId = account.id);
    try {
      widget.controller.showImportPreparationProgress('Previewing CSV...');
      final preview = await widget.controller.previewCsvImport(
        widget.pendingCsvText,
        accountId: account.id,
      );
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) =>
            _CsvImportPreviewDialog(account: account, preview: preview),
      );
      if (confirmed != true) {
        widget.controller.clearImportJobStatus();
        return;
      }
      await widget.controller.loadFromCsv(
        widget.pendingCsvText,
        accountId: account.id,
      );
      if (!context.mounted) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(builder: widget.homeBuilder),
      );
    } on FormatException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not import this file.')),
      );
    } finally {
      if (mounted) {
        setState(() => _importingAccountId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import CSV instead'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ImportJobStatusHost(
        controller: widget.importJobStatusController,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
              ],
            ),
          ),
          child: ListenableBuilder(
            listenable: _dataNotifier,
            builder: (context, _) {
              final accounts = _dataNotifier.data;
              if (accounts == null) {
                if (_dataNotifier.error != null) {
                  return const Center(child: Text('Could not load accounts.'));
                }
                return const Center(child: CircularProgressIndicator());
              }
              if (accounts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Add a manual account for this CSV',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => _showAddAccountDialog(context),
                          icon: const Icon(Icons.add_rounded, size: 22),
                          label: const Text('Add manual account'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Text(
                      'CSV import is manual. Choose the account this file belongs to; connected bank accounts update automatically.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: accounts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final a = accounts[i];
                        final importingThisAccount =
                            _importingAccountId == a.id;
                        return Material(
                          color: theme.colorScheme.surfaceContainerLowest,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: theme
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.65),
                              child: Icon(
                                switch (a.type) {
                                  AccountType.checking =>
                                    Icons.account_balance_wallet_outlined,
                                  AccountType.savings => Icons.savings_outlined,
                                  AccountType.creditCard =>
                                    Icons.credit_card_rounded,
                                },
                                size: 22,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                            ),
                            title: Text(
                              a.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SourceLabelChip(label: a.sourceLabel),
                                Text(a.type.displayLabel),
                                if (a.isPlaidConnected)
                                  Text(
                                    'CSV may duplicate synced rows',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.52),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: importingThisAccount
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    Icons.chevron_right_rounded,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.35),
                                  ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            onTap: _importingAccountId == null
                                ? () => _importForAccount(context, a)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddAccountDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add manual account'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CsvImportPreviewDialog extends StatelessWidget {
  const _CsvImportPreviewDialog({required this.account, required this.preview});

  final Account account;
  final CsvImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateRange = _dateRangeLabel(preview.startDate, preview.endDate);
    return AlertDialog(
      title: const Text('CSV import preview'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            account.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            account.isPlaidConnected
                ? 'This connected account already syncs through Plaid. Import only if this CSV covers rows Clarity does not have yet.'
                : 'This is a manual fallback import. You may need to upload newer CSV files later to keep this account current.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
            ),
          ),
          const SizedBox(height: 12),
          _PreviewLine(label: 'Date range', value: dateRange),
          _PreviewLine(label: 'Rows found', value: '${preview.parsedCount}'),
          _PreviewLine(
            label: 'New rows',
            value: '${preview.newTransactionCount}',
          ),
          _PreviewLine(label: 'Duplicates', value: '${preview.duplicateCount}'),
          _PreviewLine(
            label: 'Spending rows',
            value: '${preview.spendingCount}',
          ),
          _PreviewLine(label: 'Income rows', value: '${preview.incomeCount}'),
          if (preview.endingBalance != null)
            _PreviewLine(
              label: 'Ending balance',
              value: formatMoney(preview.endingBalance),
            ),
          if (preview.diagnostics?.layoutInferred == true) ...[
            const SizedBox(height: 10),
            Text(
              'Column layout was inferred. Review the date range before importing.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
          ],
          if (!preview.hasNewTransactions) ...[
            const SizedBox(height: 10),
            Text(
              'This looks like a duplicate import for this account. Choose another account, or delete the previous CSV upload from the account page before retrying.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: preview.hasNewTransactions
              ? () => Navigator.of(context).pop(true)
              : null,
          child: Text(preview.hasNewTransactions ? 'Import' : 'No new rows'),
        ),
      ],
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _dateRangeLabel(DateTime start, DateTime end) {
  if (start.year == end.year &&
      start.month == end.month &&
      start.day == end.day) {
    return formatShortDate(start);
  }
  return '${formatShortDate(start)} - ${formatShortDate(end)}';
}

class _AccountSelectionDataNotifier extends ChangeNotifier {
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

class _AddAccountDialog extends StatefulWidget {
  const _AddAccountDialog({required this.onCreate});

  final Future<void> Function(String name, AccountType type, double? balance)
  onCreate;

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  AccountType _type = AccountType.checking;
  var _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  double? _parseOptionalBalance(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t.replaceAll(',', ''));
    if (v == null || !v.isFinite) return null;
    return v;
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final balRaw = _balanceController.text;
    if (balRaw.trim().isNotEmpty) {
      final b = _parseOptionalBalance(balRaw);
      if (b == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enter a valid balance or leave it blank.'),
            ),
          );
        }
        return;
      }
    }
    final balance = _parseOptionalBalance(balRaw);
    setState(() => _saving = true);
    await widget.onCreate(name, _type, balance);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('New account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            Text('Type', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<AccountType>(
              segments: [
                for (final t in AccountType.values)
                  ButtonSegment<AccountType>(
                    value: t,
                    label: Text(switch (t) {
                      AccountType.checking => 'Checking',
                      AccountType.savings => 'Savings',
                      AccountType.creditCard => 'Card',
                    }),
                  ),
              ],
              selected: {_type},
              onSelectionChanged: _saving
                  ? null
                  : (next) {
                      if (next.isNotEmpty) setState(() => _type = next.first);
                    },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _balanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Current balance (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
