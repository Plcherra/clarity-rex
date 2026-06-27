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

String priorityShortLabel(int priority) {
  if (priority >= 5) {
    return 'High';
  }
  if (priority >= 4) {
    return 'Medium';
  }
  if (priority >= 3) {
    return 'Normal';
  }
  return 'Low';
}

String statusShortLabel(String status) {
  final normalized = status.trim().toLowerCase().replaceAll('_', ' ');
  if (normalized.isEmpty) {
    return 'Open';
  }
  if (normalized == 'in progress') {
    return 'In progress';
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}
