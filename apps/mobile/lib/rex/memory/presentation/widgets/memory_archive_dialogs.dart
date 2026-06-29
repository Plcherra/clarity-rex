import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';

Future<bool> confirmArchiveMemory(BuildContext context) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.memoryArchiveTitle),
      content: Text(l10n.memoryArchiveBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.commonArchive),
        ),
      ],
    ),
  );

  return confirmed == true;
}

Future<bool> confirmArchiveStructuredMemory(
  BuildContext context, {
  required String label,
}) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.memoryArchiveNamedTitle(label)),
      content: Text(l10n.memoryArchiveStructuredBody(label)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.commonArchive),
        ),
      ],
    ),
  );

  return confirmed == true;
}
