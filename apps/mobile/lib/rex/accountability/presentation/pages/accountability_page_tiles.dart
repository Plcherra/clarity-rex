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
      leading: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: context.clarityColors.textSecondary),
      icon: null,
      title: thread.title,
      subtitle: openThreadSubtitle(thread),
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
                    const SizedBox(height: RexUiTokens.space2),
                    _TileMetaRow(
                      deadline: deadline,
                      priority: priority,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RexUiTokens.space4),
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

  IconData _signalIcon() {
    return switch (signal.signalType) {
      AccountabilitySignalType.budgetRisk => Icons.pie_chart_outline_rounded,
      _ => Icons.insights_outlined,
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
      color: colors.surfaceSoft.withValues(alpha: 0.22),
      borderColor: _severityColor(colors).withValues(alpha: 0.24),
      radius: RexUiTokens.memoryTileRadius,
      padding: const EdgeInsets.all(RexUiTokens.memoryTilePaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _signalIcon(),
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
          if (signal.signalType == AccountabilitySignalType.budgetRisk) ...[
            const SizedBox(height: RexUiTokens.space4),
            Text(
              signal.signalType.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
        PopupMenuItem(value: 'pause', child: const Text('Pause')),
        PopupMenuItem(value: 'close', child: Text(l10n.commonArchive)),
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
