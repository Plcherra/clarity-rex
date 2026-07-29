part of 'accountability_page.dart';

class _GoalsSection extends StatelessWidget {
  const _GoalsSection({
    required this.plans,
    required this.planHierarchy,
    required this.onOpenPlan,
    required this.onArchivePlan,
    required this.onAddGoal,
  });

  final List<PlanRecord> plans;
  final List<PlanHierarchyItem> planHierarchy;
  final ValueChanged<PlanRecord> onOpenPlan;
  final ValueChanged<PlanRecord> onArchivePlan;
  final VoidCallback onAddGoal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final milestonesByPlanId = <String, List<PlanMilestone>>{
      for (final item in planHierarchy) item.plan.id: item.openMilestones,
    };
    return _Section(
      title: l10n.accountabilitySectionsActiveGoals,
      emptyText: l10n.accountabilitySectionsNoActiveGoals,
      emptyActionLabel: l10n.accountabilitySharedAddFirstGoal,
      onEmptyAction: onAddGoal,
      children: plans
          .map(
            (plan) => _GoalTile(
              plan: plan,
              openMilestones: milestonesByPlanId[plan.id] ?? const [],
              onTap: () => onOpenPlan(plan),
              onArchive: () => onArchivePlan(plan),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _OpenThreadsSection extends StatelessWidget {
  const _OpenThreadsSection({
    required this.threads,
    required this.onClose,
    required this.onPause,
    required this.onEdit,
  });

  final List<OpenThread> threads;
  final ValueChanged<OpenThread> onClose;
  final ValueChanged<OpenThread> onPause;
  final ValueChanged<OpenThread> onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Section(
      title: l10n.accountabilitySectionsOpenThreads,
      emptyText: l10n.accountabilitySectionsNoOpenThreads,
      children: threads
          .map(
            (thread) => _OpenThreadTile(
              thread: thread,
              onClose: () => onClose(thread),
              onPause: () => onPause(thread),
              onEdit: () => onEdit(thread),
            ),
          )
          .toList(growable: false),
    );
  }
}
