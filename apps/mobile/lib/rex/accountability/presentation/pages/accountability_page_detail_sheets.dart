part of 'accountability_page.dart';

Future<void> _showPlanDetailSheet(
  BuildContext context, {
  required PlanRecord plan,
  required Future<bool> Function({
    String? title,
    String? description,
    int? priority,
    String? status,
    DateTime? targetDate,
  })
  onSave,
  required Future<void> Function() onArchive,
}) async {
  final titleController = TextEditingController(text: plan.title);
  final notesController = TextEditingController(text: planSubtitle(plan) ?? '');
  var priority = plan.priority;
  var status = plan.status;
  DateTime? targetDate = plan.targetDate;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final colors = context.clarityColors;
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Goal details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Why this matters',
                  ),
                ),
                const SizedBox(height: 12),
                _PriorityPicker(
                  value: priority,
                  onChanged: (value) => setState(() => priority = value),
                ),
                const SizedBox(height: 12),
                _StatusPicker(
                  value: status,
                  options: const ['active', 'paused', 'completed'],
                  onChanged: (value) => setState(() => status = value),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due date'),
                  subtitle: Text(
                    targetDate == null
                        ? 'Not set'
                        : _shortDate(targetDate!),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: targetDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => targetDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await onArchive();
                      },
                      child: Text(
                        'Archive',
                        style: TextStyle(color: colors.danger),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          return;
                        }
                        final saved = await onSave(
                          title: title,
                          description: notesController.text.trim(),
                          priority: priority,
                          status: status,
                          targetDate: targetDate,
                        );
                        if (saved && sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );

  titleController.dispose();
  notesController.dispose();
}

Future<void> _showCommitmentEditSheet(
  BuildContext context, {
  required Commitment commitment,
  required Future<bool> Function({
    String? title,
    String? commitmentText,
    int? priority,
  })
  onSave,
}) async {
  final titleController = TextEditingController(text: commitment.title);
  final detailController = TextEditingController(
    text: commitmentSubtitle(commitment) ?? commitment.commitmentText,
  );
  var priority = commitment.priority;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Edit commitment',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Commitment'),
                ),
                const SizedBox(height: 12),
                _PriorityPicker(
                  value: priority,
                  onChanged: (value) => setState(() => priority = value),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        return;
                      }
                      final saved = await onSave(
                        title: title,
                        commitmentText: detailController.text.trim().isEmpty
                            ? title
                            : detailController.text.trim(),
                        priority: priority,
                      );
                      if (saved && sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  titleController.dispose();
  detailController.dispose();
}

class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: value.clamp(1, 5),
      decoration: const InputDecoration(labelText: 'Priority'),
      items: const [
        DropdownMenuItem(value: 2, child: Text('Low')),
        DropdownMenuItem(value: 3, child: Text('Normal')),
        DropdownMenuItem(value: 4, child: Text('Medium')),
        DropdownMenuItem(value: 5, child: Text('High')),
      ],
      onChanged: (next) {
        if (next != null) {
          onChanged(next);
        }
      },
    );
  }
}

class _StatusPicker extends StatelessWidget {
  const _StatusPicker({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalized = value.trim().toLowerCase();
    final selected = options.contains(normalized) ? normalized : options.first;
    return DropdownButtonFormField<String>(
      value: selected,
      decoration: const InputDecoration(labelText: 'Status'),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: Text(statusShortLabel(option)),
          ),
      ],
      onChanged: (next) {
        if (next != null) {
          onChanged(next);
        }
      },
    );
  }
}
