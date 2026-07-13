part of 'account_selection_screen.dart';

class _CsvImportPreviewDialog extends StatelessWidget {
  const _CsvImportPreviewDialog({required this.account, required this.preview});

  final Account account;
  final CsvImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final dateRange = _dateRangeLabel(preview.startDate, preview.endDate);
    return AlertDialog(
      title: Text(l10n.csvPreviewDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            account.displayName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            account.isPlaidConnected
                ? l10n.csvPreviewPlaidOverlapHint
                : l10n.csvPreviewManualFallbackHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
            ),
          ),
          const SizedBox(height: 12),
          _PreviewLine(label: l10n.csvPreviewDialogDateRange, value: dateRange),
          _PreviewLine(
            label: l10n.csvPreviewDialogRowsFound,
            value: '${preview.parsedCount}',
          ),
          _PreviewLine(
            label: l10n.csvPreviewDialogNewRows,
            value: '${preview.newTransactionCount}',
          ),
          _PreviewLine(
            label: l10n.csvPreviewDialogDuplicates,
            value: '${preview.duplicateCount}',
          ),
          _PreviewLine(
            label: l10n.csvPreviewDialogSpendingRows,
            value: '${preview.spendingCount}',
          ),
          _PreviewLine(
            label: l10n.csvPreviewDialogIncomeRows,
            value: '${preview.incomeCount}',
          ),
          if (preview.endingBalance != null)
            _PreviewLine(
              label: l10n.csvPreviewDialogEndingBalance,
              value: formatMoney(preview.endingBalance),
            ),
          if (preview.diagnostics?.layoutInferred == true) ...[
            const SizedBox(height: 10),
            Text(
              l10n.csvPreviewLayoutInferred,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
          ],
          if (!preview.hasNewTransactions) ...[
            const SizedBox(height: 10),
            Text(
              l10n.csvPreviewDuplicateImport,
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
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: preview.hasNewTransactions
              ? () => Navigator.of(context).pop(true)
              : null,
          child: Text(
            preview.hasNewTransactions
                ? l10n.commonImport
                : l10n.csvPreviewDialogNoNewRows,
          ),
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
            SnackBar(content: Text(context.l10n.addAccountDialogInvalidBalance)),
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
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.addAccountDialogTitle),
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
              decoration: InputDecoration(labelText: l10n.commonName),
            ),
            const SizedBox(height: 8),
            Text(l10n.addAccountDialogTypeLabel, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<AccountType>(
              segments: [
                for (final t in AccountType.values)
                  ButtonSegment<AccountType>(
                    value: t,
                    label: Text(accountTypeLabel(l10n, t)),
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
              decoration: InputDecoration(
                labelText: l10n.addAccountDialogBalanceLabel,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const ClarityInlineLoader(size: 20, strokeWidth: 2)
              : Text(l10n.commonSave),
        ),
      ],
    );
  }
}
