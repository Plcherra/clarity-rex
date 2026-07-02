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

String? commitmentSubtitle(Commitment commitment) {
  final text = commitment.commitmentText.trim();
  if (text.isEmpty || accountabilityTextsMatch(text, commitment.title)) {
    return null;
  }
  return text;
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

String? accountabilitySignalSubtitle(AccountabilitySignal signal) {
  final summary = signal.summary.trim();
  if (summary.isNotEmpty) {
    return summary;
  }
  final reason = signal.reason.trim();
  if (reason.isNotEmpty) {
    return reason;
  }
  return null;
}

String accountabilitySeverityLabel(
  AppLocalizations l10n,
  AccountabilitySeverity severity,
) {
  return switch (severity) {
    AccountabilitySeverity.info => l10n.commonInfo,
    AccountabilitySeverity.low => l10n.commonLow,
    AccountabilitySeverity.medium => l10n.commonMedium,
    AccountabilitySeverity.high => l10n.commonHigh,
    AccountabilitySeverity.critical => l10n.commonCritical,
    AccountabilitySeverity.unknown => l10n.commonUnknown,
  };
}
