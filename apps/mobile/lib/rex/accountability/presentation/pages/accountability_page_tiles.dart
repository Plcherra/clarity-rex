part of 'accountability_page.dart';

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.plan, required this.onArchive});

  final PlanRecord plan;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final description = plan.description ?? plan.desiredOutcome ?? '';

    return _GoalTileShell(
      icon: Icons.flag_rounded,
      title: Text(plan.title, style: _tileTitleStyle(context)),
      trailing: _GoalActions(onArchive: onArchive),
      subtitle: _SimpleGoalDetails(
        description: description,
        deadline: plan.targetDate,
        priority: plan.priority,
        status: plan.status,
      ),
    );
  }
}

class _CommitmentTile extends StatelessWidget {
  const _CommitmentTile({
    required this.commitment,
    required this.onComplete,
    required this.onMissed,
    required this.onArchive,
  });

  final Commitment commitment;
  final VoidCallback onComplete;
  final VoidCallback onMissed;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final description = commitment.commitmentText == commitment.title
        ? ''
        : commitment.commitmentText;

    return _GoalTileShell(
      icon: Icons.check_circle_outline_rounded,
      title: Text(commitment.title, style: _tileTitleStyle(context)),
      trailing: _CommitmentActions(
        onComplete: onComplete,
        onMissed: onMissed,
        onArchive: onArchive,
      ),
      subtitle: _SimpleGoalDetails(
        description: description,
        deadline: commitment.dueAt,
        priority: commitment.priority,
        status: commitment.status,
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
      iconColor: colors.textMuted,
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
    required this.onComplete,
    required this.onMissed,
    required this.onArchive,
  });

  final VoidCallback onComplete;
  final VoidCallback onMissed;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return PopupMenuButton<String>(
      tooltip: 'Commitment actions',
      color: colors.surfaceSoft,
      iconColor: colors.textMuted,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'complete', child: Text('Mark complete')),
        PopupMenuItem(value: 'missed', child: Text('Mark missed')),
        PopupMenuItem(value: 'archive', child: Text('Archive')),
      ],
      onSelected: (value) {
        switch (value) {
          case 'complete':
            onComplete();
          case 'missed':
            onMissed();
          case 'archive':
            onArchive();
        }
      },
    );
  }
}
