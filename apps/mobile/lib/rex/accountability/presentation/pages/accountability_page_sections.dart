part of 'accountability_page.dart';

class _OverviewSummary extends StatelessWidget {
  const _OverviewSummary({required this.overview});

  final AccountabilityOverview overview;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: RexUiTokens.space8,
      runSpacing: RexUiTokens.space8,
      children: [
        _SummaryPill(
          icon: Icons.warning_amber_rounded,
          label: 'Signals',
          value: overview.signals.length,
        ),
        _SummaryPill(
          icon: Icons.rule_rounded,
          label: 'Rules',
          value: overview.activeRules.length,
        ),
        _SummaryPill(
          icon: Icons.check_circle_outline_rounded,
          label: 'To do',
          value: overview.openTaskCount,
        ),
        _SummaryPill(
          icon: Icons.task_alt_rounded,
          label: 'Targets',
          value: overview.openMilestoneCount,
        ),
        if (overview.completedMilestoneCount > 0)
          _SummaryPill(
            icon: Icons.emoji_events_outlined,
            label: 'Won',
            value: overview.completedMilestoneCount,
          ),
        _SummaryPill(
          icon: Icons.flag_rounded,
          label: 'Plans',
          value: overview.activePlanCount,
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return RexSurface(
      color: colors.surfaceElevated.withValues(alpha: 0.64),
      radius: RexUiTokens.radiusPill,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.accent),
          const SizedBox(width: 7),
          Text(
            '$value $label',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalSection extends StatelessWidget {
  const _SignalSection({required this.signals});

  final List<AccountabilitySignal> signals;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Needs attention',
      emptyText: 'Nothing needs attention right now.',
      children: signals.map((signal) => _SignalTile(signal: signal)).toList(),
    );
  }
}

class _RuleSection extends StatelessWidget {
  const _RuleSection({required this.rules});

  final List<PersonalRule> rules;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Rules',
      emptyText: 'No personal rules saved yet.',
      children: rules.map((rule) => _RuleTile(rule: rule)).toList(),
    );
  }
}

class _CommitmentSection extends StatelessWidget {
  const _CommitmentSection({required this.commitments});

  final List<Commitment> commitments;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Commitments',
      emptyText: 'No open commitments right now.',
      children: commitments
          .map((commitment) => _CommitmentTile(commitment: commitment))
          .toList(),
    );
  }
}

class _PlanSection extends StatelessWidget {
  const _PlanSection({
    required this.planHierarchy,
    required this.plans,
    required this.milestones,
    required this.completedMilestones,
  });

  final List<PlanHierarchyItem> planHierarchy;
  final List<PlanRecord> plans;
  final List<PlanMilestone> milestones;
  final List<PlanMilestone> completedMilestones;

  @override
  Widget build(BuildContext context) {
    final planTiles = planHierarchy.isNotEmpty
        ? planHierarchy
              .map((item) => _PlanTile(item: item))
              .toList(growable: false)
        : plans
              .map(
                (plan) => _PlanTile(
                  item: PlanHierarchyItem(
                    plan: plan,
                    openMilestones: milestones
                        .where((milestone) => milestone.planId == plan.id)
                        .toList(growable: false),
                    completedMilestones: completedMilestones
                        .where((milestone) => milestone.planId == plan.id)
                        .toList(growable: false),
                    openCommitments: const [],
                    counts: const {},
                  ),
                ),
              )
              .toList(growable: false);
    final orphanMilestones = milestones
        .where((milestone) => !plans.any((plan) => plan.id == milestone.planId))
        .map((milestone) => _InternalMilestoneRow(milestone: milestone))
        .toList(growable: false);

    return _Section(
      title: 'Plans',
      emptyText: 'No active plans or open milestones yet.',
      children: [
        ...planTiles,
        if (orphanMilestones.isNotEmpty)
          _NestedGoalGroup(
            title: 'Unlinked milestones',
            children: orphanMilestones,
          ),
      ],
    );
  }
}

class _DuplicateWarningSection extends StatelessWidget {
  const _DuplicateWarningSection({required this.warnings});

  final List<DuplicateWarning> warnings;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Possible overlap',
      emptyText: 'No overlapping goals detected.',
      children: warnings
          .map((warning) => _DuplicateWarningTile(warning: warning))
          .toList(growable: false),
    );
  }
}
