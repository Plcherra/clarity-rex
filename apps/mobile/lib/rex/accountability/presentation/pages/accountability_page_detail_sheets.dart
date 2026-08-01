part of 'accountability_page.dart';

Future<void> _showPlanDetailSheet(
  BuildContext context, {
  required PlanRecord plan,
  required List<PlanMilestone> steps,
  required Future<bool> Function({
    String? title,
    String? description,
    int? priority,
    String? status,
    DateTime? targetDate,
    double? targetAmount,
  })
  onSave,
  required Future<void> Function() onArchive,
  required Future<void> Function() onMarkAchieved,
  required Future<PlanMilestone?> Function(String title) onAddStep,
  required Future<bool> Function(PlanMilestone milestone, bool done)
  onToggleStep,
  required Future<bool> Function(PlanMilestone milestone) onDeleteStep,
}) async {
  final l10n = context.l10n;
  final titleController = TextEditingController(text: plan.title);
  final notesController = TextEditingController(text: planSubtitle(plan) ?? '');
  final amountController = TextEditingController(
    text: plan.targetAmount == 0
        ? ''
        : plan.targetAmount
              .toStringAsFixed(plan.targetAmount % 1 == 0 ? 0 : 2),
  );
  var priority = plan.priority;
  var status = plan.status;
  DateTime? targetDate = plan.targetDate;
  // The sheet stays open across step edits, so it keeps its own copy and
  // applies each confirmed change instead of waiting for a reload.
  final planSteps = [...steps];

  await showClarityAdaptiveOverlay<void>(
    context: context,
    isScrollControlled: true,
    dialogMaxWidth: 520,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final colors = context.clarityColors;
          // Scrollable so the keyboard can never sit on top of Save, and
          // dragging the fields down puts the keyboard away without needing a
          // dropdown tap to steal focus first.
          return SingleChildScrollView(
            padding: claritySheetPadding(context),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.accountabilityDetailGoalDetails,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: l10n.commonTitle),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.commonNotes,
                    hintText: l10n.accountabilityDetailNotesHint,
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
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.accountabilityGoalAmountLabel,
                    hintText: l10n.accountabilityGoalAmountHint,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.commonDueDate),
                  subtitle: Text(
                    targetDate == null
                        ? l10n.commonNotSet
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
                const SizedBox(height: 8),
                _PlanStepsEditor(
                  steps: planSteps,
                  onAdd: () async {
                    final title = await showDialog<String>(
                      context: sheetContext,
                      builder: (_) => const _StepTitleDialog(),
                    );
                    if (title == null) return;
                    final saved = await onAddStep(title);
                    if (saved != null) {
                      setState(() => planSteps.add(saved));
                    }
                  },
                  onToggle: (milestone, done) async {
                    if (await onToggleStep(milestone, done)) {
                      setState(() {
                        planSteps[planSteps.indexOf(milestone)] = _stepWithDone(
                          milestone,
                          done,
                        );
                      });
                    }
                  },
                  onDelete: (milestone) async {
                    if (await onDeleteStep(milestone)) {
                      setState(() => planSteps.remove(milestone));
                    }
                  },
                ),
                const SizedBox(height: 8),
                if (status != _completedPlanStatus)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await onMarkAchieved();
                      },
                      icon: const Icon(Icons.emoji_events_outlined, size: 18),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.accent,
                      ),
                      label: Text(l10n.accountabilityMarkAchieved),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await onArchive();
                      },
                      child: Text(
                        l10n.commonDelete,
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
                          targetAmount: _parseGoalAmount(amountController.text),
                        );
                        if (saved && sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                      child: Text(l10n.commonSave),
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
  amountController.dispose();
}

double _parseGoalAmount(String raw) {
  final cleaned = raw.trim().replaceAll(r'$', '').replaceAll(',', '');
  if (cleaned.isEmpty) return 0;
  return double.tryParse(cleaned) ?? 0;
}

const _completedPlanStatus = 'completed';

PlanMilestone _stepWithDone(PlanMilestone milestone, bool done) {
  return PlanMilestone(
    id: milestone.id,
    planId: milestone.planId,
    title: milestone.title,
    description: milestone.description,
    milestoneType: milestone.milestoneType,
    targetDate: milestone.targetDate,
    priority: milestone.priority,
    status: done ? _completedPlanStatus : 'open',
    active: milestone.active,
    completedAt: done ? DateTime.now() : null,
  );
}

/// Steps inside the goal sheet: tick one off, add one, drop one.
class _PlanStepsEditor extends StatelessWidget {
  const _PlanStepsEditor({
    required this.steps,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
  });

  final List<PlanMilestone> steps;
  final VoidCallback onAdd;
  final void Function(PlanMilestone milestone, bool done) onToggle;
  final ValueChanged<PlanMilestone> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.clarityColors;
    final progress = goalStepsProgressLabel(l10n, steps);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.accountabilityStepsTitle,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(width: 8),
              Text(
                progress,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
              ),
            ],
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 16),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              label: Text(l10n.accountabilityAddStep),
            ),
          ],
        ),
        _GoalSteps(milestones: steps, onToggle: onToggle, onDelete: onDelete),
      ],
    );
  }
}

class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DropdownButtonFormField<int>(
      initialValue: value.clamp(1, 5),
      decoration: InputDecoration(labelText: l10n.commonPriority),
      items: [
        DropdownMenuItem(value: 2, child: Text(l10n.commonLow)),
        DropdownMenuItem(value: 3, child: Text(l10n.commonNormal)),
        DropdownMenuItem(value: 4, child: Text(l10n.commonMedium)),
        DropdownMenuItem(value: 5, child: Text(l10n.commonHigh)),
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
    final l10n = context.l10n;
    final normalized = value.trim().toLowerCase();
    final selected = options.contains(normalized) ? normalized : options.first;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: InputDecoration(labelText: l10n.commonStatus),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: Text(statusShortLabel(l10n, option)),
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
