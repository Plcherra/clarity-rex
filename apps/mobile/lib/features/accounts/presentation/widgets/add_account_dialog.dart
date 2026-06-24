import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../widgets/clarity_path_loader.dart';

class AddAccountDialog extends StatefulWidget {
  const AddAccountDialog({super.key, required this.onCreate});

  final Future<Account?> Function(
    String name,
    AccountType type,
    String? institution,
    double? balance,
  )
  onCreate;

  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  final _nameController = TextEditingController();
  final _instController = TextEditingController();
  final _balanceController = TextEditingController();
  AccountType _type = AccountType.checking;
  var _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _instController.dispose();
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
    final inst = _instController.text.trim();
    final balance = _parseOptionalBalance(_balanceController.text);
    setState(() => _saving = true);
    await widget.onCreate(name, _type, inst.isEmpty ? null : inst, balance);
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
            const SizedBox(height: 10),
            TextField(
              controller: _instController,
              textCapitalization: TextCapitalization.words,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Institution (optional)',
              ),
            ),
            const SizedBox(height: 12),
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
              ? const ClarityInlineLoader(size: 20, strokeWidth: 2)
              : const Text('Save'),
        ),
      ],
    );
  }
}
