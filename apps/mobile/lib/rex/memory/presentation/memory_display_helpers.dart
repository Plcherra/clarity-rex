import 'package:flutter/material.dart';

import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/theme/clarity_colors.dart';

bool memoryTextsMatch(String? a, String? b) {
  if (a == null || b == null) {
    return false;
  }
  return a.trim().toLowerCase() == b.trim().toLowerCase();
}

bool memoryDetailAlreadyShown({
  required String value,
  required String? context,
  String? label,
}) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  final haystack = (context ?? '').trim().toLowerCase();
  if (haystack.isEmpty) {
    return false;
  }
  if (haystack.contains(normalized)) {
    return true;
  }
  if (label != null) {
    final labeled = '${label.trim().toLowerCase()}: $normalized';
    if (haystack.contains(labeled)) {
      return true;
    }
  }
  return false;
}

String? personMemorySubtitle(PersonMemoryItem person) {
  final summary = person.summary?.trim();
  if (summary != null && summary.isNotEmpty) {
    return summary;
  }
  final relationship = person.relationship?.trim();
  if (relationship != null && relationship.isNotEmpty) {
    return relationship.memoryRecordLabel;
  }
  return null;
}

List<String> personSupplementalLabels(PersonMemoryItem person) {
  final context = personMemorySubtitle(person);
  final labels = <String>[];

  void addIfMissing(String value, {String? label}) {
    if (!memoryDetailAlreadyShown(value: value, context: context, label: label)) {
      labels.add(label == null ? value : '$label: $value');
    }
  }

  if (person.fullName != null &&
      !memoryTextsMatch(person.fullName, person.displayName)) {
    addIfMissing(person.fullName!, label: 'Name');
  }
  if (person.location != null) {
    addIfMissing(person.location!, label: 'Location');
  }
  if (person.birthday != null) {
    addIfMissing(person.birthday!, label: 'Birthday');
  }
  if (person.job != null) {
    addIfMissing(person.job!, label: 'Job');
  }
  if (person.workplace != null) {
    addIfMissing(person.workplace!, label: 'Workplace');
  }
  if (person.notes != null) {
    addIfMissing(person.notes!, label: 'Notes');
  }
  for (final date in person.importantDates) {
    addIfMissing(date, label: 'Important date');
  }
  return labels;
}

String? ruleMemorySubtitle(RuleMemoryItem rule) {
  final text = rule.ruleText.trim();
  if (text.isEmpty || memoryTextsMatch(text, rule.title)) {
    return null;
  }
  return text;
}

String? planMemorySubtitle(PlanMemoryItem plan) {
  final title = plan.title.trim();
  final description = plan.description?.trim();
  if (description != null &&
      description.isNotEmpty &&
      !memoryTextsMatch(description, title)) {
    return description;
  }
  final outcome = plan.desiredOutcome?.trim();
  if (outcome != null &&
      outcome.isNotEmpty &&
      !memoryTextsMatch(outcome, title) &&
      !memoryTextsMatch(outcome, description)) {
    return outcome;
  }
  return null;
}

String? commitmentMemorySubtitle(CommitmentMemoryItem commitment) {
  final text = commitment.commitmentText.trim();
  if (text.isEmpty || memoryTextsMatch(text, commitment.title)) {
    return null;
  }
  return text;
}

String memoryImportanceShortLabel(int importance) {
  if (importance >= 5) {
    return 'High';
  }
  if (importance >= 4) {
    return 'Medium';
  }
  if (importance >= 3) {
    return 'Normal';
  }
  return 'Low';
}

Color memoryImportanceColor(ClarityColorTokens colors, int importance) {
  if (importance >= 5) {
    return colors.danger;
  }
  if (importance >= 4) {
    return colors.accent;
  }
  return colors.textMuted;
}

String memoryUpdatedLabel(DateTime? updatedAt, DateTime? createdAt) {
  final savedAt = updatedAt ?? createdAt;
  if (savedAt == null) {
    return '';
  }
  final local = savedAt.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return 'Updated $month/$day/${local.year}';
}
