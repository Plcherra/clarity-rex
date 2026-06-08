import 'package:flutter/material.dart';

import '../../../core/models/models.dart';

Future<bool?> confirmCsvImportForPlaidAccount(
  BuildContext context,
  Account account,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Import CSV into connected account?'),
      content: Text(
        '${account.name} already syncs through Plaid. Importing a CSV here can add duplicate rows if the file overlaps with synced transactions.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue import'),
        ),
      ],
    ),
  );
}
