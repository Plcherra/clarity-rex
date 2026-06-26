part of 'accountability_page.dart';

class _GoalsSection extends StatelessWidget {
  const _GoalsSection({
    required this.plans,
    required this.onArchivePlan,
  });

  final List<PlanRecord> plans;
  final ValueChanged<PlanRecord> onArchivePlan;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Goals',
      emptyText: 'No goals yet. Add one above or tell Rex in chat.',
      children: plans
          .map(
            (plan) => _GoalTile(
              plan: plan,
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
  });

  final List<Commitment> commitments;
  final ValueChanged<Commitment> onComplete;
  final ValueChanged<Commitment> onMissed;
  final ValueChanged<Commitment> onArchive;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Commitments',
      emptyText: 'No commitments yet.',
      children: commitments
          .map(
            (commitment) => _CommitmentTile(
              commitment: commitment,
              onComplete: () => onComplete(commitment),
              onMissed: () => onMissed(commitment),
              onArchive: () => onArchive(commitment),
            ),
          )
          .toList(),
    );
  }
}
