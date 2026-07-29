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

/// Thin Goals listing: open milestone titles under a parent goal.
String? planMilestonePreviewSubtitle(List<PlanMilestone> openMilestones) {
  final titles = openMilestones
      .map((milestone) => milestone.title.trim())
      .where((title) => title.isNotEmpty)
      .toList(growable: false);
  if (titles.isEmpty) {
    return null;
  }
  if (titles.length <= 3) {
    return titles.join(' · ');
  }
  return '${titles.take(3).join(' · ')} +${titles.length - 3}';
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
