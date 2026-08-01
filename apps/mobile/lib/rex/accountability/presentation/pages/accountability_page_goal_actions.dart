part of 'accountability_page.dart';

/// Everything the user can do to a goal: finish it, reopen it, date it, and
/// work its steps. Split off the page so the widget tree stays readable.
extension _GoalMutations on _AccountabilityPageState {
  Future<void> _archivePlan(PlanRecord plan) async {
    final l10n = context.l10n;
    final confirmed = await _confirmArchive(
      title: l10n.accountabilityArchiveGoalTitle,
      body: l10n.accountabilityArchiveGoalBody(plan.title),
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true || !mounted) return;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .archivePlan(plan.id);
    if (!mounted) return;
    _showMutationResult(saved ? l10n.accountabilityGoalArchived : null);
  }

  Future<void> _markPlanAchieved(PlanRecord plan) async {
    final l10n = context.l10n;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .markPlanAchieved(plan.id);
    if (!mounted) return;
    if (saved) {
      // The one moment in the app worth marking; a snackbar undersells it.
      unawaited(showClarityCelebrationBurst(context));
    }
    _showMutationResult(saved ? l10n.accountabilityGoalAchieved : null);
  }

  Future<void> _reopenPlan(PlanRecord plan) async {
    final l10n = context.l10n;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .reopenPlan(plan.id);
    if (!mounted) return;
    _showMutationResult(saved ? l10n.accountabilityGoalReopened : null);
  }

  /// For goals saved before a due date was required, and any Rex save without
  /// one — a goal with no deadline has nothing to press against.
  Future<void> _setPlanDueDate(PlanRecord plan) async {
    final l10n = context.l10n;
    final picked = await showDatePicker(
      context: context,
      initialDate: plan.targetDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .updatePlan(plan.id, targetDateIso: dateOnlyIso(picked));
    if (!mounted) return;
    _showMutationResult(saved ? l10n.accountabilityGoalUpdated : null);
  }

  Future<bool> _toggleStep(PlanMilestone milestone, bool done) async {
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .setMilestoneDone(milestone.id, done: done);
    if (!mounted) return saved;
    if (!saved) {
      _showMutationResult(null);
      return saved;
    }
    if (done) {
      unawaited(
        showClarityCelebrationBurst(context, scale: _stepScale(milestone)),
      );
    }
    return saved;
  }

  /// Clearing the last step earns the full burst: the goal is now in reach,
  /// which is a bigger moment than any single step before it.
  ClarityCelebrationScale _stepScale(PlanMilestone milestone) {
    final hierarchy = ref.read(accountabilityProvider).overview?.planHierarchy;
    final remaining = openGoalStepCount(hierarchy ?? const [], milestone.planId);
    return remaining == 0
        ? ClarityCelebrationScale.finish
        : ClarityCelebrationScale.step;
  }

  /// From the list, where there is no sheet open to show the tick landing.
  Future<void> _toggleStepFromTile(PlanMilestone milestone, bool done) async {
    final l10n = context.l10n;
    final saved = await _toggleStep(milestone, done);
    if (!mounted || !saved) return;
    _showMutationResult(l10n.accountabilityStepUpdated);
  }

  Future<bool> _deleteStep(PlanMilestone milestone) async {
    final l10n = context.l10n;
    final confirmed = await _confirmArchive(
      title: l10n.accountabilityDeleteStepTitle,
      body: l10n.accountabilityDeleteStepBody(milestone.title),
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true || !mounted) return false;
    final saved = await ref
        .read(accountabilityProvider.notifier)
        .deleteMilestone(milestone.id);
    if (!mounted) return saved;
    _showMutationResult(saved ? l10n.accountabilityStepDeleted : null);
    return saved;
  }

  Future<void> _openPlanDetail(PlanRecord plan) async {
    final hierarchy = ref.read(accountabilityProvider).overview?.planHierarchy;
    await _showPlanDetailSheet(
      context,
      plan: plan,
      steps: goalStepsFor(hierarchy ?? const [], plan.id),
      onMarkAchieved: () => _markPlanAchieved(plan),
      onAddStep: (title) => ref
          .read(accountabilityProvider.notifier)
          .addMilestone(planId: plan.id, title: title),
      onToggleStep: _toggleStep,
      onDeleteStep: _deleteStep,
      onSave:
          ({
            title,
            description,
            priority,
            status,
            targetDate,
            targetAmount,
          }) async {
        final saved = await ref
            .read(accountabilityProvider.notifier)
            .updatePlan(
              plan.id,
              title: title,
              description: description,
              priority: priority,
              status: status,
              targetDateIso: targetDate == null ? null : dateOnlyIso(targetDate),
              targetAmount: targetAmount,
            );
        if (mounted) {
          _showMutationResult(
            saved ? context.l10n.accountabilityGoalUpdated : null,
          );
        }
        return saved;
      },
      onArchive: () => _archivePlan(plan),
    );
  }
}
