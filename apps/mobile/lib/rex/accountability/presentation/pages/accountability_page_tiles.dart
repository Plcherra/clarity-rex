part of 'accountability_page.dart';

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.plan,
    required this.onTap,
    required this.onArchive,
  });

  final PlanRecord plan;
  final VoidCallback onTap;
  final VoidCallback onArchive;

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
      trailing: _GoalActions(onArchive: onArchive),
    );
  }
}

class _CommitmentTile extends StatelessWidget {
  const _CommitmentTile({
    required this.commitment,
    required this.onComplete,
    required this.onMissed,
    required this.onArchive,
    required this.onEdit,
  });

  final Commitment commitment;
  final VoidCallback onComplete;
  final VoidCallback onMissed;
  final VoidCallback onArchive;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _AccountabilityTile(
      leading: Checkbox(
        value: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: (_) => onComplete(),
      ),
      icon: null,
      title: commitment.title,
      subtitle: commitmentSubtitle(commitment),
      deadline: commitment.dueAt,
      priority: commitment.priority,
      status: commitment.status,
      trailing: _CommitmentActions(
        onEdit: onEdit,
        onMissed: onMissed,
        onArchive: onArchive,
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

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final theme = Theme.of(context);

    return Material(
      color: colors.surfaceSoft.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RexUiTokens.space12,
            vertical: RexUiTokens.space8,
          ),
          child: Row(
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
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: RexUiTokens.space4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: RexUiTokens.space4),
                    _TileMetaRow(
                      deadline: deadline,
                      priority: priority,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RexUiTokens.space8),
              _StatusChip(status: status),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _TileMetaRow extends StatelessWidget {
  const _TileMetaRow({required this.deadline, required this.priority});

  final DateTime? deadline;
  final int priority;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final parts = <String>[
      priorityShortLabel(priority),
      if (deadline != null) 'Due ${_shortDate(deadline!)}',
    ];
    return Text(
      parts.join(' · '),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: colors.textSecondary,
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
        statusShortLabel(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GoalActions extends StatelessWidget {
  const _GoalActions({required this.onArchive});

  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return PopupMenuButton<String>(
      tooltip: 'Goal actions',
      color: colors.surfaceSoft,
      icon: Icon(Icons.more_horiz_rounded, color: colors.textMuted, size: 18),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'archive', child: Text('Archive')),
      ],
      onSelected: (value) {
        if (value == 'archive') {
          onArchive();
        }
      },
    );
  }
}

class _CommitmentActions extends StatelessWidget {
  const _CommitmentActions({
    required this.onEdit,
    required this.onMissed,
    required this.onArchive,
  });

  final VoidCallback onEdit;
  final VoidCallback onMissed;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return PopupMenuButton<String>(
      tooltip: 'Commitment actions',
      color: colors.surfaceSoft,
      icon: Icon(Icons.more_horiz_rounded, color: colors.textMuted, size: 18),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'missed', child: Text('Mark missed')),
        PopupMenuItem(value: 'archive', child: Text('Archive')),
      ],
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit();
          case 'missed':
            onMissed();
          case 'archive':
            onArchive();
        }
      },
    );
  }
}
