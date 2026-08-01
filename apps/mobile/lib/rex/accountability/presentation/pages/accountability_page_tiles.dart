part of 'accountability_page.dart';

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.plan,
    required this.steps,
    required this.onTap,
    required this.onArchive,
    required this.onToggleStep,
    required this.onMarkAchieved,
    required this.onSetDueDate,
  });

  final PlanRecord plan;
  final List<PlanMilestone> steps;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final void Function(PlanMilestone milestone, bool done) onToggleStep;
  final VoidCallback onMarkAchieved;
  final VoidCallback onSetDueDate;

  @override
  Widget build(BuildContext context) {
    return _AccountabilityTile(
      onTap: onTap,
      leading: _PriorityDot(priority: plan.priority),
      icon: Icons.flag_rounded,
      title: plan.title,
      subtitle: planSubtitle(plan),
      deadline: plan.targetDate,
      priority: plan.priority,
      status: plan.status,
      metaSuffix: [
        ?goalAmountLabel(plan),
        ?goalStepsProgressLabel(context.l10n, steps),
      ].join(' · '),
      trailing: _GoalActions(
        onArchive: onArchive,
        onMarkAchieved: onMarkAchieved,
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GoalSteps(milestones: steps, onToggle: onToggleStep, maxVisible: 4),
          _GoalDeadlineBar(plan: plan, onSetDueDate: onSetDueDate),
        ],
      ),
    );
  }
}

/// A goal the user finished — kept in reach, with a way back if it was early.
class _AchievedGoalTile extends StatelessWidget {
  const _AchievedGoalTile({required this.plan, required this.onReopen});

  final PlanRecord plan;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final achievedOn = plan.completedAt;
    return _AccountabilityTile(
      leading: Icon(Icons.emoji_events_rounded, size: 18, color: colors.accent),
      title: plan.title,
      subtitle: achievedOn == null
          ? planSubtitle(plan)
          : l10n.accountabilityAchievedOn(_shortDate(achievedOn)),
      deadline: null,
      priority: plan.priority,
      status: plan.status,
      showMeta: false,
      trailing: IconButton(
        onPressed: onReopen,
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        tooltip: l10n.accountabilityReopenGoal,
        icon: Icon(Icons.undo_rounded, color: colors.textMuted),
      ),
    );
  }
}

class _OpenThreadTile extends StatelessWidget {
  const _OpenThreadTile({
    required this.thread,
    required this.onClose,
    required this.onPause,
    required this.onEdit,
  });

  final OpenThread thread;
  final VoidCallback onClose;
  final VoidCallback onPause;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _AccountabilityTile(
      leading: Icon(
        Icons.chat_bubble_outline_rounded,
        size: 18,
        color: context.clarityColors.textSecondary,
      ),
      icon: null,
      title: thread.title,
      subtitle: openThreadSubtitle(context.l10n, thread),
      deadline: thread.updatedAt,
      priority: 3,
      status: thread.status,
      trailing: _OpenThreadActions(
        onEdit: onEdit,
        onPause: onPause,
        onClose: onClose,
      ),
    );
  }
}

class _AccountabilityTile extends StatelessWidget {
  const _AccountabilityTile({
    required this.leading,
    this.icon,
    required this.title,
    required this.subtitle,
    required this.deadline,
    required this.priority,
    required this.status,
    required this.trailing,
    this.onTap,
    this.metaSuffix,
    this.footer,
    this.showMeta = true,
  });

  final Widget leading;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final DateTime? deadline;
  final int priority;
  final String status;
  final Widget trailing;
  final VoidCallback? onTap;

  /// Extra fact on the meta line, such as how many steps are done.
  final String? metaSuffix;

  /// Sits under the tile body, full width — the goal's steps go here.
  final Widget? footer;
  final bool showMeta;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final theme = Theme.of(context);

    return Material(
      color: colors.surfaceSoft.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(RexUiTokens.memoryTileRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(RexUiTokens.memoryTileRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RexUiTokens.memoryTilePaddingH,
            vertical: RexUiTokens.memoryTilePaddingV,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: leading,
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: RexUiTokens.space8),
                    Icon(icon, color: colors.accent, size: 16),
                  ],
                  const SizedBox(width: RexUiTokens.space8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: RexUiTokens.space2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.textMuted,
                              height: 1.25,
                            ),
                          ),
                        ],
                        if (showMeta) ...[
                          const SizedBox(height: RexUiTokens.space2),
                          _TileMetaRow(
                            deadline: deadline,
                            priority: priority,
                            suffix: metaSuffix,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: RexUiTokens.space4),
                  _StatusChip(status: status),
                  trailing,
                ],
              ),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

class _TileMetaRow extends StatelessWidget {
  const _TileMetaRow({
    required this.deadline,
    required this.priority,
    this.suffix,
  });

  final DateTime? deadline;
  final int priority;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final parts = <String>[
      priorityShortLabel(l10n, priority),
      if (deadline != null) _dueDateLabel(l10n, deadline!),
      ?suffix,
    ];
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: colors.textMuted,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    Color dotColor;
    if (priority >= 5) {
      dotColor = colors.danger;
    } else if (priority >= 4) {
      dotColor = colors.accent;
    } else {
      dotColor = colors.textMuted;
    }
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return Padding(
      padding: const EdgeInsets.only(top: 2, right: 2),
      child: Text(
        statusShortLabel(context.l10n, status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GoalActions extends StatelessWidget {
  const _GoalActions({required this.onArchive, required this.onMarkAchieved});

  final VoidCallback onArchive;
  final VoidCallback onMarkAchieved;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l10n.accountabilityTilesGoalActionsTooltip,
      color: colors.surfaceSoft,
      icon: Icon(Icons.more_horiz_rounded, color: colors.textMuted, size: 18),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'achieved',
          child: Text(l10n.accountabilityMarkAchieved),
        ),
        PopupMenuItem(value: 'delete', child: Text(l10n.commonDelete)),
      ],
      onSelected: (value) {
        switch (value) {
          case 'achieved':
            onMarkAchieved();
          case 'delete':
            onArchive();
        }
      },
    );
  }
}

class _OpenThreadActions extends StatelessWidget {
  const _OpenThreadActions({
    required this.onEdit,
    required this.onPause,
    required this.onClose,
  });

  final VoidCallback onEdit;
  final VoidCallback onPause;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l10n.accountabilityTilesOpenThreadActionsTooltip,
      color: colors.surfaceSoft,
      icon: Icon(Icons.more_horiz_rounded, color: colors.textMuted, size: 18),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
        PopupMenuItem(value: 'pause', child: Text(l10n.commonPause)),
        PopupMenuItem(value: 'close', child: Text(l10n.commonDelete)),
      ],
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit();
          case 'pause':
            onPause();
          case 'close':
            onClose();
        }
      },
    );
  }
}
