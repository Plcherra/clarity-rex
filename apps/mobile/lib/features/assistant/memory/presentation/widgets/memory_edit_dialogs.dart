import 'package:flutter/material.dart';

import 'package:clarity/features/assistant/memory/data/memory_models.dart';

class StructuredEditDialog extends StatefulWidget {
  const StructuredEditDialog({
    required this.title,
    required this.primaryLabel,
    required this.primaryValue,
    required this.detailLabel,
    required this.importanceLabel,
    required this.importance,
    required this.status,
    required this.active,
    super.key,
    this.detailValue,
    this.extraLabel,
    this.extraValue,
    this.aliasesValue,
  });

  final String title;
  final String primaryLabel;
  final String primaryValue;
  final String detailLabel;
  final String? detailValue;
  final String? extraLabel;
  final String? extraValue;
  final String? aliasesValue;
  final String importanceLabel;
  final int importance;
  final String status;
  final bool active;

  @override
  State<StructuredEditDialog> createState() => _StructuredEditDialogState();
}

class _StructuredEditDialogState extends State<StructuredEditDialog> {
  late final TextEditingController _primaryController;
  late final TextEditingController _detailController;
  late final TextEditingController _extraController;
  late final TextEditingController _aliasesController;
  late final TextEditingController _statusController;
  late double _importance;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _primaryController = TextEditingController(text: widget.primaryValue);
    _detailController = TextEditingController(text: widget.detailValue ?? '');
    _extraController = TextEditingController(text: widget.extraValue ?? '');
    _aliasesController = TextEditingController(text: widget.aliasesValue ?? '');
    _statusController = TextEditingController(text: widget.status);
    _importance = widget.importance.toDouble();
    _active = widget.active;
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _detailController.dispose();
    _extraController.dispose();
    _aliasesController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _primaryController,
              decoration: InputDecoration(labelText: widget.primaryLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailController,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: widget.detailLabel,
                border: const OutlineInputBorder(),
              ),
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
            if (widget.aliasesValue != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _aliasesController,
                decoration: const InputDecoration(
                  labelText: 'Aliases',
                  helperText: 'Comma-separated',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _statusController,
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(widget.importanceLabel),
                Expanded(
                  child: Slider(
                    value: _importance,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _importance.round().toString(),
                    onChanged: (value) => setState(() => _importance = value),
                  ),
                ),
                Text(_importance.round().toString()),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
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
        aliases: _splitCommaText(_aliasesController.text),
        importance: _importance.round(),
        status: _statusController.text.trim(),
        active: _active,
      ),
    );
  }
}

class PendingCandidateEditDialog extends StatefulWidget {
  const PendingCandidateEditDialog({required this.candidate, super.key});

  final PendingMemoryCandidateItem candidate;

  @override
  State<PendingCandidateEditDialog> createState() =>
      _PendingCandidateEditDialogState();
}

class _PendingCandidateEditDialogState
    extends State<PendingCandidateEditDialog> {
  late final TextEditingController _proposalController;
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _proposalController = TextEditingController(
      text: widget.candidate.editableProposal,
    );
    _reasonController = TextEditingController(
      text: widget.candidate.reasonLabel ?? '',
    );
  }

  @override
  void dispose() {
    _proposalController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit memory review'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _proposalController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'What Rex should know',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Why Rex paused here',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }

  void _submit() {
    final proposal = _proposalController.text.trim();
    if (proposal.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      PendingCandidateEditResult(
        proposal: proposal,
        reason: _nullableText(_reasonController.text),
      ),
    );
  }
}

class MemoryEditDialog extends StatefulWidget {
  const MemoryEditDialog({required this.memory, super.key});

  final MemoryItem memory;

  @override
  State<MemoryEditDialog> createState() => _MemoryEditDialogState();
}

class _MemoryEditDialogState extends State<MemoryEditDialog> {
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
    return AlertDialog(
      title: const Text('Edit memory'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<MemoryType>(
              initialValue: _memoryType,
              decoration: const InputDecoration(labelText: 'Type'),
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
              decoration: const InputDecoration(
                labelText: 'Memory',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Importance'),
                Expanded(
                  child: Slider(
                    value: _importance,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _importance.round().toString(),
                    onChanged: (value) => setState(() => _importance = value),
                  ),
                ),
                Text(_importance.round().toString()),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
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

class MemoryEditResult {
  const MemoryEditResult({
    required this.memoryType,
    required this.content,
    required this.importance,
    required this.active,
  });

  final MemoryType? memoryType;
  final String content;
  final int importance;
  final bool active;
}

class PendingCandidateEditResult {
  const PendingCandidateEditResult({
    required this.proposal,
    required this.reason,
  });

  final String proposal;
  final String? reason;
}

class StructuredEditResult {
  const StructuredEditResult({
    required this.primary,
    required this.importance,
    required this.status,
    required this.active,
    this.detail,
    this.extra,
    this.aliases = const [],
  });

  final String primary;
  final String? detail;
  final String? extra;
  final List<String> aliases;
  final int importance;
  final String status;
  final bool active;

  List<String> get extraList => _splitCommaText(extra ?? '');
}

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _splitCommaText(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
