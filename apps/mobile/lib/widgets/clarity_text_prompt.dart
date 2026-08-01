import 'package:flutter/material.dart';

import '../core/l10n/app_l10n.dart';
import '../core/layout/web_centered_dialog.dart';

/// Asks for one line of text and returns it trimmed, or null if cancelled.
///
/// The dialog owns its [TextEditingController]. Callers used to create one
/// and dispose it in a `finally` after awaiting the dialog, which tears the
/// field down while the route is still animating out — the field is still on
/// screen at that point, and its render object detaches mid-frame.
Future<String?> showClarityTextPrompt(
  BuildContext context, {
  required String title,
  required String fieldLabel,
  String initialValue = '',
  String? description,
  String? confirmLabel,
  int? maxLength,
  TextInputType? keyboardType,
  bool autocorrect = true,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => wrapWebCenteredDialog(
      dialogContext,
      _TextPromptDialog(
        title: title,
        fieldLabel: fieldLabel,
        initialValue: initialValue,
        description: description,
        confirmLabel: confirmLabel,
        maxLength: maxLength,
        keyboardType: keyboardType,
        autocorrect: autocorrect,
      ),
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.fieldLabel,
    required this.initialValue,
    required this.description,
    required this.confirmLabel,
    required this.maxLength,
    required this.keyboardType,
    required this.autocorrect,
  });

  final String title;
  final String fieldLabel;
  final String initialValue;
  final String? description;
  final String? confirmLabel;
  final int? maxLength;
  final TextInputType? keyboardType;
  final bool autocorrect;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _field = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_field.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final description = widget.description;

    final field = TextField(
      controller: _field,
      autofocus: true,
      autocorrect: widget.autocorrect,
      keyboardType: widget.keyboardType,
      maxLength: widget.maxLength,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.fieldLabel,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) => _submit(),
    );

    return AlertDialog(
      title: Text(widget.title),
      content: description == null
          ? field
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(description), const SizedBox(height: 16), field],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel ?? l10n.commonSave),
        ),
      ],
    );
  }
}
