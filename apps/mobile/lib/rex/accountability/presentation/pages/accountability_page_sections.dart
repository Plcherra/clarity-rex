part of 'accountability_page.dart';

class _GoalsSection extends StatelessWidget {
  const _GoalsSection({
    required this.plans,
    required this.onOpenPlan,
    required this.onArchivePlan,
    required this.onAddGoal,
  });

  final List<PlanRecord> plans;
  final ValueChanged<PlanRecord> onOpenPlan;
  final ValueChanged<PlanRecord> onArchivePlan;
  final VoidCallback onAddGoal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Section(
      title: l10n.accountabilitySectionsActiveGoals,
      emptyText: l10n.accountabilitySectionsNoActiveGoals,
      emptyActionLabel: l10n.accountabilitySharedAddFirstGoal,
      onEmptyAction: onAddGoal,
      children: plans
          .map(
            (plan) => _GoalTile(
              plan: plan,
              onTap: () => onOpenPlan(plan),
              onArchive: () => onArchivePlan(plan),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _CommitmentSection extends StatelessWidget {
  const _CommitmentSection({
    required this.commitments,
    required this.onComplete,
    required this.onMissed,
    required this.onArchive,
    required this.onEdit,
  });

  final List<Commitment> commitments;
  final ValueChanged<Commitment> onComplete;
  final ValueChanged<Commitment> onMissed;
  final ValueChanged<Commitment> onArchive;
  final ValueChanged<Commitment> onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Section(
      title: l10n.accountabilitySectionsOpenCommitments,
      emptyText: l10n.accountabilitySectionsNoOpenCommitments,
      children: commitments
          .map(
            (commitment) => _CommitmentTile(
              commitment: commitment,
              onComplete: () => onComplete(commitment),
              onMissed: () => onMissed(commitment),
              onArchive: () => onArchive(commitment),
              onEdit: () => onEdit(commitment),
            ),
          )
          .toList(),
    );
  }
}
