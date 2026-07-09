import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_path_loader.dart';

/// Editable person confirm card for relationship memory proposals.
class ClarityPersonConfirmCard extends StatefulWidget {
  const ClarityPersonConfirmCard({
    super.key,
    required this.action,
    this.onConfirm,
    this.onDismiss,
  });

  final ClarityActionCard action;
  final ValueChanged<ClarityActionCard>? onConfirm;
  final ValueChanged<ClarityActionCard>? onDismiss;

  @override
  State<ClarityPersonConfirmCard> createState() =>
      _ClarityPersonConfirmCardState();
}

class _ClarityPersonConfirmCardState extends State<ClarityPersonConfirmCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _relationshipController;
  late final TextEditingController _birthdayController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final card = widget.action.personCard ?? const ClarityPersonCardData();
    _nameController = TextEditingController(text: card.displayName);
    _relationshipController = TextEditingController(text: card.relationship);
    _birthdayController = TextEditingController(text: card.birthday);
    _notesController = TextEditingController(text: card.notes);
    for (final controller in [
      _nameController,
      _relationshipController,
      _birthdayController,
      _notesController,
    ]) {
      controller.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _relationshipController,
      _birthdayController,
      _notesController,
    ]) {
      controller.removeListener(_onFieldChanged);
      controller.dispose();
    }
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  int get _filledCount {
    return [
      _nameController.text,
      _relationshipController.text,
      _birthdayController.text,
      _notesController.text,
    ].where((value) => value.trim().isNotEmpty).length;
  }

  int get _typedExtraLength {
    final original = widget.action.personCard ?? const ClarityPersonCardData();
    var total = 0;
    void countDelta(String current, String initial) {
      final trimmed = current.trim();
      if (trimmed != initial.trim()) {
        total += trimmed.length;
      }
    }

    countDelta(_nameController.text, original.displayName);
    countDelta(_relationshipController.text, original.relationship);
    countDelta(_birthdayController.text, original.birthday);
    countDelta(_notesController.text, original.notes);
    return total;
  }

  ClarityActionCard _confirmedAction() {
    final personCard = ClarityPersonCardData(
      displayName: _nameController.text.trim(),
      relationship: _relationshipController.text.trim(),
      birthday: _birthdayController.text.trim(),
      notes: _notesController.text.trim(),
      mergeHint: widget.action.personCard?.mergeHint,
      relatedSummary: widget.action.personCard?.relatedSummary,
    );
    return widget.action.copyWith(
      title: personCard.displayName.isEmpty
          ? widget.action.title
          : personCard.displayName,
      body: [
        if (personCard.relationship.isNotEmpty) personCard.relationship,
        if (personCard.displayName.isNotEmpty) personCard.displayName,
        if (personCard.birthday.isNotEmpty) personCard.birthday,
        if (personCard.notes.isNotEmpty) personCard.notes,
      ].join(' · '),
      personCard: personCard,
      editableFields: const [
        'display_name',
        'relationship',
        'birthday',
        'notes',
      ],
    );
  }

  Future<void> _handleDismiss() async {
    final onDismiss = widget.onDismiss;
    if (onDismiss == null) {
      return;
    }
    if (_typedExtraLength > 10) {
      final l10n = context.l10n;
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(l10n.personConfirmDiscardTitle),
            content: Text(l10n.personConfirmDiscardBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonKeepEditing),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.commonDiscard),
              ),
            ],
          );
        },
      );
      if (discard != true || !mounted) {
        return;
      }
    }
    onDismiss(widget.action);
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final canSave = _filledCount >= 2 && !action.isApplying;
    final mergeHint = widget.action.personCard?.mergeHint?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.42),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.personConfirmTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (mergeHint != null && mergeHint.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                mergeHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 14),
            _PersonField(
              controller: _nameController,
              label: l10n.personConfirmNameLabel,
              enabled: !action.isApplying,
            ),
            const SizedBox(height: 10),
            _PersonField(
              controller: _relationshipController,
              label: l10n.personConfirmRelationshipLabel,
              enabled: !action.isApplying,
            ),
            const SizedBox(height: 10),
            _PersonField(
              controller: _birthdayController,
              label: l10n.personConfirmBirthdayLabel,
              enabled: !action.isApplying,
            ),
            const SizedBox(height: 10),
            _PersonField(
              controller: _notesController,
              label: l10n.personConfirmNotesLabel,
              enabled: !action.isApplying,
              minLines: 2,
              maxLines: 4,
            ),
            if (_filledCount < 2) ...[
              const SizedBox(height: 10),
              Text(
                l10n.personConfirmTwoFieldsRequired,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (widget.onConfirm != null)
              FilledButton.icon(
                onPressed: canSave
                    ? () => widget.onConfirm!(_confirmedAction())
                    : null,
                icon: action.isApplying
                    ? const ClarityInlineLoader(size: 18, strokeWidth: 2)
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(l10n.commonConfirm),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            if (widget.onDismiss != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: action.isApplying ? null : _handleDismiss,
                icon: const Icon(Icons.close_rounded, size: 20),
                label: Text(l10n.commonDismiss),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PersonField extends StatelessWidget {
  const _PersonField({
    required this.controller,
    required this.label,
    required this.enabled,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return TextField(
      controller: controller,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: colors.surfaceSoft.withValues(alpha: 0.72),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
