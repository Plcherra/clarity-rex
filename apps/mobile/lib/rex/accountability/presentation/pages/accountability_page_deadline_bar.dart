part of 'accountability_page.dart';

/// The time a goal has left, as a bar that fills on its own.
///
/// Colour is the whole message: it stays quiet for most of the run, warms as
/// the date closes in, and goes red once it passes. A goal with no due date
/// gets an invitation to set one instead of a bar with nothing to say.
class _GoalDeadlineBar extends StatelessWidget {
  const _GoalDeadlineBar({required this.plan, required this.onSetDueDate});

  final PlanRecord plan;
  final VoidCallback onSetDueDate;

  @override
  Widget build(BuildContext context) {
    final progress = goalDeadlineProgress(plan);
    if (progress == null) {
      return _SetDueDatePrompt(onTap: onSetDueDate);
    }

    final colors = context.clarityColors;
    final tint = _urgencyColor(colors, progress.urgency);

    return Padding(
      padding: const EdgeInsets.only(top: RexUiTokens.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: _AnimatedFill(
              value: progress.elapsed,
              color: tint,
              trackColor: colors.surfaceSoft.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: RexUiTokens.space4),
          Text(
            _timeLeftLabel(context.l10n, progress),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: progress.urgency == GoalDeadlineUrgency.steady
                  ? colors.textMuted
                  : tint,
              fontWeight: progress.urgency == GoalDeadlineUrgency.steady
                  ? FontWeight.w500
                  : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _timeLeftLabel(AppLocalizations l10n, GoalDeadlineProgress progress) {
  if (progress.isDueToday) {
    return l10n.accountabilityDueToday;
  }
  if (progress.isOverdue) {
    return l10n.accountabilityDaysOver(-progress.daysLeft);
  }
  return l10n.accountabilityDaysLeft(progress.daysLeft);
}

Color _urgencyColor(ClarityColorTokens colors, GoalDeadlineUrgency urgency) {
  switch (urgency) {
    case GoalDeadlineUrgency.steady:
      return colors.accent;
    case GoalDeadlineUrgency.closing:
      return colors.warning;
    case GoalDeadlineUrgency.urgent:
      return Color.lerp(colors.warning, colors.danger, 0.5)!;
    case GoalDeadlineUrgency.overdue:
      return colors.danger;
  }
}

/// The fill slides to its new length rather than jumping, so ticking a goal
/// forward reads as movement instead of a redraw.
class _AnimatedFill extends StatelessWidget {
  const _AnimatedFill({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? value : 0, end: value),
      duration: still ? Duration.zero : const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (context, filled, _) => LinearProgressIndicator(
        value: filled,
        minHeight: 5,
        backgroundColor: trackColor,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class _SetDueDatePrompt extends StatelessWidget {
  const _SetDueDatePrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.event_outlined, size: 15, color: colors.textMuted),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: colors.textMuted,
        ),
        label: Text(
          context.l10n.accountabilitySetDueDate,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
        ),
      ),
    );
  }
}
