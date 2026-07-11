import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/rex/memory/data/person_memory_model.dart';
import 'package:clarity/rex/memory/presentation/memory_display_helpers.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/theme/clarity_sheet_insets.dart';

class PersonEditResult {
  const PersonEditResult({
    required this.displayName,
    required this.relationship,
    required this.summary,
    required this.birthday,
    this.delete = false,
  });

  final String displayName;
  final String? relationship;
  final String? summary;
  final String? birthday;
  final bool delete;
}

Future<PersonEditResult?> showPersonEditSheet(
  BuildContext context, {
  required PersonMemoryItem person,
}) {
  return showClarityModalBottomSheet<PersonEditResult>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => MemoryPersonEditSheet(person: person),
  );
}

class MemoryPersonEditSheet extends StatefulWidget {
  const MemoryPersonEditSheet({super.key, required this.person});

  final PersonMemoryItem person;

  @override
  State<MemoryPersonEditSheet> createState() => _MemoryPersonEditSheetState();
}

class _MemoryPersonEditSheetState extends State<MemoryPersonEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _relationshipController;
  late final TextEditingController _summaryController;
  late final TextEditingController _birthdayController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.person.displayName);
    _relationshipController = TextEditingController(
      text: widget.person.relationship ?? '',
    );
    _summaryController = TextEditingController(
      text: widget.person.summary ?? '',
    );
    _birthdayController = TextEditingController(
      text: widget.person.birthday ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _summaryController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  String get _initial {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return '?';
    }
    return String.fromCharCode(name.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final updatedLabel = memoryUpdatedLabel(
      l10n,
      widget.person.updatedAt,
      widget.person.createdAt,
    );

    return Padding(
      padding: claritySheetPadding(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.accent.withValues(alpha: 0.18),
                  child: Text(
                    _initial,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.commonName,
                      filled: false,
                      border: const UnderlineInputBorder(),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: colors.textMuted.withValues(alpha: 0.35),
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: colors.accent),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _relationshipController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.commonType,
                hintText: l10n.memoryEditPersonRelationshipHint,
                helperText: l10n.memoryEditPersonRelationshipHelper,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _birthdayController,
              keyboardType: TextInputType.datetime,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: l10n.memoryDisplayBirthday,
                hintText: l10n.memoryEditPersonBirthdayHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _summaryController,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(labelText: l10n.commonSummary),
            ),
            if (updatedLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                updatedLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: _confirmDelete,
                  style: TextButton.styleFrom(foregroundColor: colors.danger),
                  child: Text(l10n.commonDelete),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _submit, child: Text(l10n.commonSave)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.commonDelete),
        content: Text(
          l10n.memoryEditPersonDeleteBody(widget.person.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(
        PersonEditResult(
          displayName: widget.person.displayName,
          relationship: widget.person.relationship,
          summary: widget.person.summary,
          birthday: widget.person.birthday,
          delete: true,
        ),
      );
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    final relationship = _relationshipController.text.trim();
    final summary = _summaryController.text.trim();
    final birthday = _birthdayController.text.trim();
    Navigator.of(context).pop(
      PersonEditResult(
        displayName: name,
        relationship: relationship.isEmpty ? null : relationship,
        summary: summary.isEmpty ? null : summary,
        birthday: birthday.isEmpty ? null : birthday,
      ),
    );
  }
}
