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
    final l10n = context.l10n;
    final parts = <String>[
      priorityShortLabel(l10n, priority),
      if (deadline != null) _dueDateLabel(l10n, deadline!),
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

class _SignalTile extends StatelessWidget {
  const _SignalTile({required this.signal});

  final AccountabilitySignal signal;

  Color _severityColor(ClarityColorTokens colors) {
    return switch (signal.severity) {
      AccountabilitySeverity.critical ||
      AccountabilitySeverity.high => colors.danger,
      AccountabilitySeverity.medium => colors.warning,
      AccountabilitySeverity.low || AccountabilitySeverity.info => colors.accent,
      AccountabilitySeverity.unknown => colors.textMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final subtitle = accountabilitySignalSubtitle(signal);
    final action = signal.recommendedAction?.trim();

    return RexSurface(
      color: colors.surfaceSoft.withValues(alpha: 0.35),
      borderColor: _severityColor(colors).withValues(alpha: 0.24),
      padding: const EdgeInsets.all(RexUiTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.insights_outlined,
                size: 16,
                color: _severityColor(colors),
              ),
              const SizedBox(width: RexUiTokens.space8),
              Expanded(
                child: Text(
                  signal.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: RexUiTokens.space8),
              _SeverityChip(severity: signal.severity),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: RexUiTokens.space4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                height: 1.35,
              ),
            ),
          ],
          if (action != null && action.isNotEmpty) ...[
            const SizedBox(height: RexUiTokens.space4),
            Text(
              action,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (signal.status != AccountabilityStatus.unknown &&
              signal.status != AccountabilityStatus.active) ...[
            const SizedBox(height: RexUiTokens.space4),
            Text(
              statusShortLabel(l10n, signal.status.name),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});

  final AccountabilitySeverity severity;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return Text(
      accountabilitySeverityLabel(context.l10n, severity),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: colors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
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
  const _GoalActions({required this.onArchive});

  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l10n.accountabilityTilesGoalActionsTooltip,
      color: colors.surfaceSoft,
      icon: Icon(Icons.more_horiz_rounded, color: colors.textMuted, size: 18),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'archive', child: Text(l10n.commonArchive)),
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
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l10n.accountabilityTilesCommitmentActionsTooltip,
      color: colors.surfaceSoft,
      icon: Icon(Icons.more_horiz_rounded, color: colors.textMuted, size: 18),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
        PopupMenuItem(
          value: 'missed',
          child: Text(l10n.accountabilityTilesMarkMissed),
        ),
        PopupMenuItem(value: 'archive', child: Text(l10n.commonArchive)),
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
