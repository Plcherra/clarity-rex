import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';
import 'package:clarity/core/layout/clarity_adaptive_overlay.dart';
import 'package:clarity/rex/memory/presentation/memory_display_helpers.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_edit_dialogs.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_edit_shared_widgets.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/theme/clarity_sheet_insets.dart';

Future<StructuredEditResult?> showStructuredMemoryEditSheet(
  BuildContext context, {
  required String title,
  required String typeLabel,
  required String primaryLabel,
  required String primaryValue,
  required String detailLabel,
  required String? detailValue,
  required String importanceLabel,
  required int importance,
  required String status,
  required bool active,
  required DateTime? updatedAt,
  required DateTime? createdAt,
  String? extraLabel,
  String? extraValue,
  bool showImportance = true,
  bool showActive = true,
}) {
  return showClarityAdaptiveOverlay<StructuredEditResult>(
    context: context,
    isScrollControlled: true,
    dialogMaxWidth: 520,
    builder: (sheetContext) => MemoryStructuredEditSheet(
      title: title,
      typeLabel: typeLabel,
      primaryLabel: primaryLabel,
      primaryValue: primaryValue,
      detailLabel: detailLabel,
      detailValue: detailValue,
      extraLabel: extraLabel,
      extraValue: extraValue,
      importanceLabel: importanceLabel,
      importance: importance,
      status: status,
      active: active,
      updatedAt: updatedAt,
      createdAt: createdAt,
      showImportance: showImportance,
      showActive: showActive,
    ),
  );
}

class MemoryStructuredEditSheet extends StatefulWidget {
  const MemoryStructuredEditSheet({
    super.key,
    required this.title,
    required this.typeLabel,
    required this.primaryLabel,
    required this.primaryValue,
    required this.detailLabel,
    required this.detailValue,
    required this.importanceLabel,
    required this.importance,
    required this.status,
    required this.active,
    required this.updatedAt,
    required this.createdAt,
    this.extraLabel,
    this.extraValue,
    this.showImportance = true,
    this.showActive = true,
  });

  final String title;
  final String typeLabel;
  final String primaryLabel;
  final String primaryValue;
  final String detailLabel;
  final String? detailValue;
  final String? extraLabel;
  final String? extraValue;
  final String importanceLabel;
  final int importance;
  final String status;
  final bool active;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final bool showImportance;
  final bool showActive;

  @override
  State<MemoryStructuredEditSheet> createState() =>
      _MemoryStructuredEditSheetState();
}

class _MemoryStructuredEditSheetState extends State<MemoryStructuredEditSheet> {
  late final TextEditingController _primaryController;
  late final TextEditingController _detailController;
  late final TextEditingController _extraController;
  late double _importance;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _primaryController = TextEditingController(text: widget.primaryValue);
    _detailController = TextEditingController(text: widget.detailValue ?? '');
    _extraController = TextEditingController(text: widget.extraValue ?? '');
    _importance = widget.importance.toDouble();
    _active = widget.active;
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _detailController.dispose();
    _extraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final updatedLabel = memoryUpdatedLabel(
      l10n,
      widget.updatedAt,
      widget.createdAt,
    );

    return Padding(
      padding: claritySheetPadding(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(labelText: l10n.commonType),
              child: Text(
                widget.typeLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _primaryController,
              decoration: InputDecoration(labelText: widget.primaryLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailController,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(labelText: widget.detailLabel),
            ),
            if (widget.extraLabel != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _extraController,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(labelText: widget.extraLabel),
              ),
            ],
            if (widget.showImportance) ...[
              const SizedBox(height: 12),
              MemoryEditImportanceSlider(
                label: widget.importanceLabel,
                value: _importance,
                onChanged: (value) => setState(() => _importance = value),
              ),
            ],
            if (widget.showActive)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.commonActive),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            if (updatedLabel.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  updatedLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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

  void _submit() {
    final primary = _primaryController.text.trim();
    if (primary.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      StructuredEditResult(
        primary: primary,
        detail: nullableEditText(_detailController.text),
        extra: nullableEditText(_extraController.text),
        importance: _importance.round(),
        status: widget.status,
        active: _active,
      ),
    );
  }
}
