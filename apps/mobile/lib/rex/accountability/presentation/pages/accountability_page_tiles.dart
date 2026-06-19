part of 'accountability_page.dart';

class _SignalTile extends StatelessWidget {
  const _SignalTile({required this.signal});

  final AccountabilitySignal signal;

  @override
  Widget build(BuildContext context) {
    final accent = _severityColor(signal.severity);

    return _GoalTileShell(
      icon: _signalIcon(signal.signalType),
      iconColor: accent,
      title: Text(signal.title, style: _tileTitleStyle(context)),
      subtitle: _RecordSubtitle(
        text: signal.summary.isEmpty ? signal.reason : signal.summary,
        chips: [
          signal.signalType.label,
          signal.severity.label,
          if (signal.sourceRefs.isNotEmpty)
            _sourceLabel(signal.sourceRefs.first),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule});

  final PersonalRule rule;

  @override
  Widget build(BuildContext context) {
    return _GoalTileShell(
      icon: Icons.rule_rounded,
      title: Text(rule.title),
      subtitle: _RecordSubtitle(
        text: rule.ruleText,
        chips: [
          rule.ruleType.accountabilityLabel,
          'Priority ${rule.priority}',
          rule.enforcementStyle.accountabilityLabel,
        ],
      ),
    );
  }
}

class _CommitmentTile extends StatelessWidget {
  const _CommitmentTile({required this.commitment});

  final Commitment commitment;

  @override
  Widget build(BuildContext context) {
    return _GoalTileShell(
      icon: Icons.check_circle_outline_rounded,
      title: Text(commitment.title),
      subtitle: _RecordSubtitle(
        text: commitment.commitmentText,
        chips: [
          commitment.commitmentType.accountabilityLabel,
          commitment.status.accountabilityLabel,
          if (commitment.dueAt != null) 'Due ${_shortDate(commitment.dueAt!)}',
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.item});

  final PlanHierarchyItem item;

  @override
  Widget build(BuildContext context) {
    final plan = item.plan;
    final milestones = item.openMilestones;
    final completed = item.completedMilestones;
    final details = plan.description ?? plan.desiredOutcome ?? '';
    final tasks = <Commitment>[
      ...item.openCommitments,
      for (final milestone in milestones) ...milestone.openCommitments,
    ];
    final achievementTargets = milestones
        .where((milestone) => milestone.openCommitments.isEmpty)
        .take(3)
        .toList(growable: false);

    return Column(
      children: [
        _GoalTileShell(
          icon: Icons.flag_rounded,
          title: Text(plan.title),
          trailing: const _PlanActions(),
          subtitle: _RecordSubtitle(
            text: details,
            chips: [
              plan.planType.accountabilityLabel,
              plan.status.accountabilityLabel,
              if (plan.targetDate != null)
                'Target ${_shortDate(plan.targetDate!)}',
            ],
          ),
        ),
        if (tasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 8, 4, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: tasks
                  .map((commitment) => _ChecklistRow(commitment: commitment))
                  .toList(growable: false),
            ),
          ),
        if (completed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 0, 4, 10),
            child: _MilestoneBadgeWrap(milestones: completed),
          ),
        if (achievementTargets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 0, 4, 10),
            child: _UpcomingTargets(milestones: achievementTargets),
          ),
        if (milestones.length >= 8)
          const Padding(
            padding: EdgeInsets.fromLTRB(48, 0, 4, 10),
            child: _InlineWarning(text: 'This plan has many open milestones.'),
          ),
        if (milestones.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 0, 4, 10),
            child: _NestedGoalGroup(
              title: 'Milestones',
              children: milestones
                  .map(
                    (milestone) => _InternalMilestoneRow(milestone: milestone),
                  )
                  .toList(growable: false),
            ),
          ),
      ],
    );
  }
}

class _PlanActions extends StatelessWidget {
  const _PlanActions();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Plan actions',
      color: RexUiTokens.surfaceRaised,
      iconColor: RexUiTokens.textMuted,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'archive', child: Text('Archive')),
      ],
      onSelected: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan edits go through confirmed memory changes.'),
          ),
        );
      },
    );
  }
}

class _UpcomingTargets extends StatelessWidget {
  const _UpcomingTargets({required this.milestones});

  final List<PlanMilestone> milestones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next targets',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: RexUiTokens.text,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: milestones
              .map(
                (milestone) => _MetaChip(
                  label: milestone.targetDate == null
                      ? milestone.title
                      : '${milestone.title} - ${_shortDate(milestone.targetDate!)}',
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _MilestoneBadgeWrap extends StatelessWidget {
  const _MilestoneBadgeWrap({required this.milestones});

  final List<PlanMilestone> milestones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Completed milestones',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: milestones
              .map(
                (milestone) => _StatusChip(
                  icon: Icons.emoji_events_outlined,
                  label: milestone.title,
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _NestedGoalGroup extends StatelessWidget {
  const _NestedGoalGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RexSurface(
      color: RexUiTokens.surfaceSoft.withValues(alpha: 0.66),
      borderColor: RexUiTokens.border.withValues(alpha: 0.62),
      radius: RexUiTokens.radiusSmall,
      padding: const EdgeInsets.all(RexUiTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title / ${children.length}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: RexUiTokens.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: RexUiTokens.space4),
          ...children,
        ],
      ),
    );
  }
}

class _InternalMilestoneRow extends StatelessWidget {
  const _InternalMilestoneRow({required this.milestone});

  final PlanMilestone milestone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.subdirectory_arrow_right_rounded,
            size: 18,
            color: RexUiTokens.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: RexUiTokens.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _MetaChip(
                      label: milestone.milestoneType.accountabilityLabel,
                    ),
                    _MetaChip(label: milestone.status.accountabilityLabel),
                    if (milestone.targetDate != null)
                      _MetaChip(
                        label: 'Due ${_shortDate(milestone.targetDate!)}',
                      ),
                  ],
                ),
                if (milestone.openCommitments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Column(
                    children: milestone.openCommitments
                        .map(
                          (commitment) => _ChecklistRow(commitment: commitment),
                        )
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.commitment});

  final Commitment commitment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 17,
            color: RexUiTokens.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              commitment.commitmentText.isEmpty
                  ? commitment.title
                  : commitment.commitmentText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: RexUiTokens.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DuplicateWarningTile extends StatelessWidget {
  const _DuplicateWarningTile({required this.warning});

  final DuplicateWarning warning;

  @override
  Widget build(BuildContext context) {
    return _GoalTileShell(
      icon: Icons.merge_type_rounded,
      title: Text(warning.title),
      subtitle: _RecordSubtitle(
        text:
            'Multiple active ${warning.recordType.accountabilityLabel}s may overlap.',
        chips: [
          warning.recordType.accountabilityLabel,
          '${warning.recordIds.length} records',
        ],
      ),
    );
  }
}
