import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/memory_l10n.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/theme/clarity_sheet_insets.dart';

enum MemoryCreateKind {
  fact,
  preference,
  person,
  rule,
}

class FlatMemoryCreateResult {
  const FlatMemoryCreateResult({
    required this.memoryType,
    required this.content,
    required this.importance,
    this.memoryCategory,
  });

  final MemoryType memoryType;
  final String content;
  final int importance;
  final String? memoryCategory;
}

class PersonCreateResult {
  const PersonCreateResult({
    required this.displayName,
    this.relationship,
    this.summary,
    required this.importance,
  });

  final String displayName;
  final String? relationship;
  final String? summary;
  final int importance;
}

class StructuredCreateResult {
  const StructuredCreateResult({
    required this.title,
    required this.detail,
    required this.importance,
    this.extra,
  });

  final String title;
  final String detail;
  final int importance;
  final String? extra;
}

const memoryCreateCategories = memoryCreateCategoryKeys;

Future<MemoryCreateKind?> showMemoryCreateTypePicker(BuildContext context) {
  final l10n = context.l10n;
  return showClarityModalBottomSheet<MemoryCreateKind>(
    context: context,
    builder: (sheetContext) {
      final options = [
        (MemoryCreateKind.fact, l10n.memoryCreateFact),
        (MemoryCreateKind.preference, l10n.memoryCreatePreference),
        (MemoryCreateKind.person, l10n.commonPerson),
        (MemoryCreateKind.rule, l10n.memoryCreateRule),
      ];
      return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  l10n.memoryCreateChooseType,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final option in options)
                ListTile(
                  title: Text(option.$2),
                  onTap: () => Navigator.of(sheetContext).pop(option.$1),
                ),
            ],
          ),
        );
    },
  );
}

Future<FlatMemoryCreateResult?> showFlatMemoryCreateSheet(
  BuildContext context, {
  required MemoryCreateKind kind,
}) {
  return showClarityModalBottomSheet<FlatMemoryCreateResult>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _FlatMemoryCreateSheet(kind: kind),
  );
}

Future<PersonCreateResult?> showPersonCreateSheet(BuildContext context) {
  return showClarityModalBottomSheet<PersonCreateResult>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => const _PersonCreateSheet(),
  );
}

Future<StructuredCreateResult?> showStructuredCreateSheet(
  BuildContext context, {
  required String title,
  required String primaryLabel,
  required String detailLabel,
  String? extraLabel,
}) {
  return showClarityModalBottomSheet<StructuredCreateResult>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _StructuredCreateSheet(
      title: title,
      primaryLabel: primaryLabel,
      detailLabel: detailLabel,
      extraLabel: extraLabel,
    ),
  );
}

class _FlatMemoryCreateSheet extends StatefulWidget {
  const _FlatMemoryCreateSheet({required this.kind});

  final MemoryCreateKind kind;

  @override
  State<_FlatMemoryCreateSheet> createState() => _FlatMemoryCreateSheetState();
}

class _FlatMemoryCreateSheetState extends State<_FlatMemoryCreateSheet> {
  late final TextEditingController _contentController;
  late MemoryType _memoryType;
  late String _category;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
    _memoryType = widget.kind == MemoryCreateKind.preference
        ? MemoryType.preference
        : MemoryType.fact;
    _category = widget.kind == MemoryCreateKind.preference
        ? 'Preferences'
        : 'Facts';
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: claritySheetPadding(context),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.kind == MemoryCreateKind.preference
                  ? l10n.memoryCreatePreferenceTitle
                  : l10n.memoryCreateFactTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: l10n.memoryCreateCategoryLabel),
              items: memoryCreateCategoryKeys
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(memoryCreateCategoryLabel(l10n, category)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _category = value);
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  child: Text(l10n.memoryCreateSave),
                ),
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
      FlatMemoryCreateResult(
        memoryType: _memoryType,
        content: content,
        importance: 3,
        memoryCategory: _category,
      ),
    );
  }
}

class _PersonCreateSheet extends StatefulWidget {
  const _PersonCreateSheet();

  @override
  State<_PersonCreateSheet> createState() => _PersonCreateSheetState();
}

class _PersonCreateSheetState extends State<_PersonCreateSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _relationshipController;
  late final TextEditingController _summaryController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _relationshipController = TextEditingController();
    _summaryController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: claritySheetPadding(context),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.memoryCreatePersonTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.commonName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _relationshipController,
              decoration: InputDecoration(labelText: l10n.memoryCreateRelationshipLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _summaryController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: l10n.commonSummary),
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
                FilledButton(
                  onPressed: _submit,
                  child: Text(l10n.memoryCreateSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final displayName = _nameController.text.trim();
    if (displayName.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      PersonCreateResult(
        displayName: displayName,
        relationship: _relationshipController.text.trim().isEmpty
            ? null
            : _relationshipController.text.trim(),
        summary: _summaryController.text.trim().isEmpty
            ? null
            : _summaryController.text.trim(),
        importance: 3,
      ),
    );
  }
}

class _StructuredCreateSheet extends StatefulWidget {
  const _StructuredCreateSheet({
    required this.title,
    required this.primaryLabel,
    required this.detailLabel,
    this.extraLabel,
  });

  final String title;
  final String primaryLabel;
  final String detailLabel;
  final String? extraLabel;

  @override
  State<_StructuredCreateSheet> createState() => _StructuredCreateSheetState();
}

class _StructuredCreateSheetState extends State<_StructuredCreateSheet> {
  late final TextEditingController _primaryController;
  late final TextEditingController _detailController;
  late final TextEditingController _extraController;
  var _importance = 3.0;

  @override
  void initState() {
    super.initState();
    _primaryController = TextEditingController();
    _detailController = TextEditingController();
    _extraController = TextEditingController();
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
    final l10n = context.l10n;
    return Padding(
      padding: claritySheetPadding(context),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _primaryController,
              decoration: InputDecoration(labelText: widget.primaryLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: widget.detailLabel),
            ),
            if (widget.extraLabel != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _extraController,
                decoration: InputDecoration(labelText: widget.extraLabel),
              ),
            ],
            const SizedBox(height: 12),
            _ImportanceSlider(
              label: l10n.commonPriority,
              value: _importance,
              onChanged: (value) => setState(() => _importance = value),
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
                FilledButton(
                  onPressed: _submit,
                  child: Text(l10n.memoryCreateSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final title = _primaryController.text.trim();
    final detail = _detailController.text.trim();
    if (title.isEmpty || detail.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      StructuredCreateResult(
        title: title,
        detail: detail,
        importance: _importance.round(),
        extra: _extraController.text.trim().isEmpty
            ? null
            : _extraController.text.trim(),
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
    final colors = context.clarityColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colors.textSecondary)),
        Slider(
          value: value,
          min: 1,
          max: 5,
          divisions: 4,
          label: value.round().toString(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
