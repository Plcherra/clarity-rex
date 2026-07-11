import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/memory_display_helpers.dart';
import 'package:clarity/rex/memory/presentation/memory_l10n.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_edit_dialogs.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/theme/clarity_sheet_insets.dart';

Future<MemoryEditResult?> showFlatMemoryEditSheet(
  BuildContext context, {
  required MemoryItem memory,
}) {
  return showClarityModalBottomSheet<MemoryEditResult>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => MemoryFlatEditSheet(memory: memory),
  );
}

class MemoryFlatEditSheet extends StatefulWidget {
  const MemoryFlatEditSheet({super.key, required this.memory});

  final MemoryItem memory;

  @override
  State<MemoryFlatEditSheet> createState() => _MemoryFlatEditSheetState();
}

class _MemoryFlatEditSheetState extends State<MemoryFlatEditSheet> {
  late final TextEditingController _contentController;
  late MemoryType _memoryType;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.memory.content);
    _memoryType = widget.memory.memoryType;
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
    final updatedLabel = memoryUpdatedLabel(
      l10n,
      widget.memory.updatedAt,
      widget.memory.createdAt,
    );

    return Padding(
      padding: claritySheetPadding(context),
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
                      child: Text(type.localizedLabel(l10n)),
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
        importance: widget.memory.importance,
        active: _active,
      ),
    );
  }
}
