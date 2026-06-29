import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/memory_display_helpers.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_edit_dialogs.dart';
import 'package:clarity/theme/clarity_colors.dart';

Future<MemoryEditResult?> showMemoryEditSheet(
  BuildContext context, {
  required MemoryItem memory,
}) {
  return showModalBottomSheet<MemoryEditResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _MemoryEditSheet(memory: memory),
  );
}

Future<StructuredEditResult?> showStructuredEditSheet(
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
}) {
  return showModalBottomSheet<StructuredEditResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _StructuredEditSheet(
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
    ),
  );
}

class _MemoryEditSheet extends StatefulWidget {
  const _MemoryEditSheet({required this.memory});

  final MemoryItem memory;

  @override
  State<_MemoryEditSheet> createState() => _MemoryEditSheetState();
}

class _MemoryEditSheetState extends State<_MemoryEditSheet> {
  late final TextEditingController _contentController;
  late MemoryType _memoryType;
  late double _importance;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.memory.content);
    _memoryType = widget.memory.memoryType;
    _importance = widget.memory.importance.toDouble();
    _active = widget.memory.active;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final updatedLabel = memoryUpdatedLabel(
      l10n,
      widget.memory.updatedAt,
      widget.memory.createdAt,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.memoryEditEditMemoryTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MemoryType>(
              initialValue: _memoryType,
              decoration: InputDecoration(labelText: l10n.commonType),
              items: MemoryType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      enabled: type != MemoryType.other,
                      child: Text(type.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _memoryType = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.commonSummary,
                hintText: l10n.memoryEditSummaryHint,
              ),
            ),
            const SizedBox(height: 12),
            _ImportanceSlider(
              label: l10n.commonImportance,
              value: _importance,
              onChanged: (value) => setState(() => _importance = value),
            ),
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
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      MemoryEditResult(
        memoryType: _memoryType == MemoryType.other ? null : _memoryType,
        content: content,
        importance: _importance.round(),
        active: _active,
      ),
    );
  }
}

class _StructuredEditSheet extends StatefulWidget {
  const _StructuredEditSheet({
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

  @override
  State<_StructuredEditSheet> createState() => _StructuredEditSheetState();
}

class _StructuredEditSheetState extends State<_StructuredEditSheet> {
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final updatedLabel = memoryUpdatedLabel(
      l10n,
      widget.updatedAt,
      widget.createdAt,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
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
            const SizedBox(height: 12),
            _ImportanceSlider(
              label: widget.importanceLabel,
              value: _importance,
              onChanged: (value) => setState(() => _importance = value),
            ),
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
        detail: _nullableText(_detailController.text),
        extra: _nullableText(_extraController.text),
        importance: _importance.round(),
        status: widget.status,
        active: _active,
      ),
    );
  }
}

class _ImportanceSlider extends StatelessWidget {
  const _ImportanceSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label),
        Expanded(
          child: Slider(
            value: value,
            min: 1,
            max: 5,
            divisions: 4,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
        Text(value.round().toString()),
      ],
    );
  }
}

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
