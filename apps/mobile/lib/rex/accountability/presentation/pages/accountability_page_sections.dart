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
    return _Section(
      title: 'Active Goals',
      emptyText: 'No active goals yet.',
      emptyActionLabel: 'Add your first goal',
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
    return _Section(
      title: 'Open Commitments',
      emptyText: 'No open commitments.',
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
