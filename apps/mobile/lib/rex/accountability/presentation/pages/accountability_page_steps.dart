part of 'accountability_page.dart';

/// The steps under a goal — milestones, shown as something you can tick off.
///
/// A goal is reached through its steps, so they live on the goal itself
/// instead of being a line of grey text that cannot be touched.
class _GoalSteps extends StatelessWidget {
  const _GoalSteps({
    required this.milestones,
    required this.onToggle,
    this.onDelete,
    this.maxVisible,
  });

  final List<PlanMilestone> milestones;
  final void Function(PlanMilestone milestone, bool done) onToggle;
  final ValueChanged<PlanMilestone>? onDelete;

  /// Keeps a long checklist from swallowing the goal list.
  final int? maxVisible;

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) return const SizedBox.shrink();

    final colors = context.clarityColors;
    final ordered = sortedGoalSteps(milestones);
    final limit = maxVisible;
    final visible = limit == null || ordered.length <= limit
        ? ordered
        : ordered.take(limit).toList(growable: false);
    final hidden = ordered.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final milestone in visible)
          _GoalStepRow(
            milestone: milestone,
            onToggle: (done) => onToggle(milestone, done),
            onDelete: onDelete == null ? null : () => onDelete!(milestone),
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(left: 26, top: RexUiTokens.space2),
            child: Text(
              '+$hidden',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
            ),
          ),
      ],
    );
  }
}

class _GoalStepRow extends StatelessWidget {
  const _GoalStepRow({
    required this.milestone,
    required this.onToggle,
    this.onDelete,
  });

  final PlanMilestone milestone;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final theme = Theme.of(context);
    final done = isGoalStepDone(milestone);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onToggle(!done),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: done ? colors.accent : colors.textMuted,
              ),
              const SizedBox(width: RexUiTokens.space8),
              Expanded(
                child: Text(
                  milestone.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: done ? colors.textMuted : colors.textSecondary,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: colors.textMuted,
                  ),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  tooltip: context.l10n.commonDelete,
                  icon: Icon(Icons.close_rounded, color: colors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One short field — a step is a title, nothing else.
class _StepTitleDialog extends StatefulWidget {
  const _StepTitleDialog();

  @override
  State<_StepTitleDialog> createState() => _StepTitleDialogState();
}

class _StepTitleDialogState extends State<_StepTitleDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.accountabilityAddStep),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: l10n.commonTitle,
          hintText: l10n.accountabilityAddStepHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonSave)),
      ],
    );
  }
}
