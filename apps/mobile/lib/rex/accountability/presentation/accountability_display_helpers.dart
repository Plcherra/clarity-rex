import '../../../l10n/app_localizations.dart';
import 'package:clarity/rex/accountability/data/accountability_models.dart';

bool accountabilityTextsMatch(String? a, String? b) {
  if (a == null || b == null) {
    return false;
  }
  return a.trim().toLowerCase() == b.trim().toLowerCase();
}

String? planSubtitle(PlanRecord plan) {
  final title = plan.title.trim();
  final description = plan.description?.trim();
  if (description != null &&
      description.isNotEmpty &&
      !accountabilityTextsMatch(description, title)) {
    return description;
  }
  final outcome = plan.desiredOutcome?.trim();
  if (outcome != null &&
      outcome.isNotEmpty &&
      !accountabilityTextsMatch(outcome, title) &&
      !accountabilityTextsMatch(outcome, description)) {
    return outcome;
  }
  return null;
}

/// Open and finished steps for one goal, from the overview's plan hierarchy.
List<PlanMilestone> goalStepsFor(
  List<PlanHierarchyItem> hierarchy,
  String planId,
) {
  for (final item in hierarchy) {
    if (item.plan.id == planId) {
      return [...item.openMilestones, ...item.completedMilestones];
    }
  }
  return const [];
}

/// Steps still open for one goal, or null when the goal is not in the list.
///
/// Null and zero mean different things here: a goal we cannot find is not a
/// goal with nothing left to do.
int? openGoalStepCount(List<PlanHierarchyItem> hierarchy, String planId) {
  for (final item in hierarchy) {
    if (item.plan.id == planId) return item.openMilestones.length;
  }
  return null;
}

bool isGoalStepDone(PlanMilestone milestone) {
  final status = milestone.status.trim().toLowerCase();
  return status == 'completed' ||
      status == 'done' ||
      milestone.completedAt != null;
}

/// Steps still to do come first — what is left matters more than what is done.
List<PlanMilestone> sortedGoalSteps(List<PlanMilestone> milestones) {
  final sorted = [...milestones];
  sorted.sort((a, b) {
    final aDone = isGoalStepDone(a);
    if (aDone != isGoalStepDone(b)) return aDone ? 1 : -1;
    final aDate = a.targetDate;
    final bDate = b.targetDate;
    if (aDate != null && bDate != null) return aDate.compareTo(bDate);
    if (aDate != null) return -1;
    if (bDate != null) return 1;
    return 0;
  });
  return sorted;
}

String? goalStepsProgressLabel(
  AppLocalizations l10n,
  List<PlanMilestone> milestones,
) {
  if (milestones.isEmpty) return null;
  final done = milestones.where(isGoalStepDone).length;
  return l10n.accountabilityStepsDone(done, milestones.length);
}

String? openThreadSubtitle(AppLocalizations l10n, OpenThread thread) {
  final summary = thread.summary?.trim();
  if (summary != null &&
      summary.isNotEmpty &&
      !accountabilityTextsMatch(summary, thread.title)) {
    return summary;
  }
  return l10n.accountabilityTilesOpenThreadDefaultSubtitle;
}

String priorityShortLabel(AppLocalizations l10n, int priority) {
  if (priority >= 5) {
    return l10n.commonHigh;
  }
  if (priority >= 4) {
    return l10n.commonMedium;
  }
  if (priority >= 3) {
    return l10n.commonNormal;
  }
  return l10n.commonLow;
}

String statusShortLabel(AppLocalizations l10n, String status) {
  final normalized = status.trim().toLowerCase().replaceAll('_', ' ');
  if (normalized.isEmpty) {
    return l10n.accountabilityStatusOpen;
  }
  if (normalized == 'in progress') {
    return l10n.accountabilityStatusInProgress;
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}
