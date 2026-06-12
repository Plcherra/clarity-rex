import 'package:flutter/material.dart';

Future<bool> confirmArchiveMemory(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Archive saved information?'),
      content: const Text(
        'This saved information will stop being used in future conversations. It will remain in information history.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Archive'),
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
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Archive $label?'),
      content: Text(
        'This $label will stop being used as active context. It will remain in information history.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Archive'),
        ),
      ],
    ),
  );

  return confirmed == true;
}
