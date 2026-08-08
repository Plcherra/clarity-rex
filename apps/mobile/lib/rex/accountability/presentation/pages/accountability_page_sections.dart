part of 'accountability_page.dart';

class _GoalsSection extends StatelessWidget {
  const _GoalsSection({
    required this.plans,
    required this.planHierarchy,
    required this.onOpenPlan,
    required this.onArchivePlan,
    required this.onAddGoal,
    required this.onToggleStep,
    required this.onMarkAchieved,
    required this.onSetDueDate,
  });

  final List<PlanRecord> plans;
  final List<PlanHierarchyItem> planHierarchy;
  final ValueChanged<PlanRecord> onOpenPlan;
  final ValueChanged<PlanRecord> onArchivePlan;
  final VoidCallback onAddGoal;
  final void Function(PlanMilestone milestone, bool done) onToggleStep;
  final ValueChanged<PlanRecord> onMarkAchieved;
  final ValueChanged<PlanRecord> onSetDueDate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final moneyNeeds = buildGoalMoneyNeeds(plans);
    return _Section(
      title: l10n.accountabilitySectionsActiveGoals,
      emptyText: l10n.accountabilitySectionsNoActiveGoals,
      emptyActionLabel: l10n.accountabilitySharedAddFirstGoal,
      onEmptyAction: onAddGoal,
      children: [
        ...plans.map(
          (plan) => _GoalTile(
            plan: plan,
            steps: goalStepsFor(planHierarchy, plan.id),
            onTap: () => onOpenPlan(plan),
            onArchive: () => onArchivePlan(plan),
            onToggleStep: onToggleStep,
            onMarkAchieved: () => onMarkAchieved(plan),
            onSetDueDate: () => onSetDueDate(plan),
          ),
        ),
        if (moneyNeeds.isNotEmpty) _MoneyNeedsSummary(summary: moneyNeeds),
      ],
    );
  }
}

class _AchievedGoalsSection extends StatelessWidget {
  const _AchievedGoalsSection({required this.plans, required this.onReopen});

  final List<PlanRecord> plans;
  final ValueChanged<PlanRecord> onReopen;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return _Section(
      title: l10n.accountabilitySectionsAchievedGoals,
      emptyText: l10n.accountabilitySectionsNoAchievedGoals,
      children: plans
          .map(
            (plan) =>
                _AchievedGoalTile(plan: plan, onReopen: () => onReopen(plan)),
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
    required this.onOpen,
  });

  final List<OpenThread> threads;
  final ValueChanged<OpenThread> onClose;
  final ValueChanged<OpenThread> onPause;
  final ValueChanged<OpenThread> onEdit;
  final ValueChanged<OpenThread> onOpen;

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
              onTap: () => onOpen(thread),
            ),
          )
          .toList(growable: false),
    );
  }
}
