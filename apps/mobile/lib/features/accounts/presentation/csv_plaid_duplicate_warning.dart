import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/models.dart';

Future<bool?> confirmCsvImportForPlaidAccount(
  BuildContext context,
  Account account,
) {
  final l10n = context.l10n;
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.csvPlaidWarningTitle),
      content: Text(l10n.csvPlaidWarningContent(account.displayName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.csvPlaidWarningContinue),
        ),
      ],
    ),
  );
}
