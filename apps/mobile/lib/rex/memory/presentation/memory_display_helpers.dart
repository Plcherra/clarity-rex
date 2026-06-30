import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/memory_l10n.dart';
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

List<String> personSupplementalLabels(
  AppLocalizations l10n,
  PersonMemoryItem person,
) {
  final context = personMemorySubtitle(person);
  final labels = <String>[];

  void addIfMissing(String value, {String? label}) {
    if (!memoryDetailAlreadyShown(value: value, context: context, label: label)) {
      labels.add(label == null ? value : '$label: $value');
    }
  }

  if (person.fullName != null &&
      !memoryTextsMatch(person.fullName, person.displayName)) {
    addIfMissing(person.fullName!, label: l10n.commonName);
  }
  if (person.location != null) {
    addIfMissing(person.location!, label: l10n.memoryDisplayLocation);
  }
  if (person.birthday != null) {
    addIfMissing(person.birthday!, label: l10n.memoryDisplayBirthday);
  }
  if (person.job != null) {
    addIfMissing(person.job!, label: l10n.memoryDisplayJob);
  }
  if (person.workplace != null) {
    addIfMissing(person.workplace!, label: l10n.memoryDisplayWorkplace);
  }
  if (person.notes != null) {
    addIfMissing(person.notes!, label: l10n.commonNotes);
  }
  for (final date in person.importantDates) {
    addIfMissing(date, label: l10n.memoryDisplayImportantDate);
  }
  return labels;
}

List<String> planMilestonePreviewLabels(
  AppLocalizations l10n,
  List<PlanMilestoneMemoryItem> milestones,
) {
  return milestones
      .map((milestone) {
        final preview = milestone.previewLabel;
        if (preview.isEmpty) {
          return null;
        }
        return '${localizedMemoryRecordLabel(l10n, 'plan_milestone')}: $preview';
      })
      .whereType<String>()
      .toList(growable: false);
}

List<String> entityEventPreviewLabels(
  AppLocalizations l10n,
  List<EntityEventItem> events,
) {
  return events
      .map((event) {
        final preview = event.previewLabel;
        if (preview.isEmpty) {
          return null;
        }
        return '${localizedMemoryRecordLabel(l10n, event.eventType)}: $preview';
      })
      .whereType<String>()
      .toList(growable: false);
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

String memoryImportanceShortLabel(AppLocalizations l10n, int importance) {
  if (importance >= 5) {
    return l10n.commonHigh;
  }
  if (importance >= 4) {
    return l10n.commonMedium;
  }
  if (importance >= 3) {
    return l10n.commonNormal;
  }
  return l10n.commonLow;
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

String memoryUpdatedLabel(
  AppLocalizations l10n,
  DateTime? updatedAt,
  DateTime? createdAt,
) {
  final savedAt = updatedAt ?? createdAt;
  if (savedAt == null) {
    return '';
  }
  final local = savedAt.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return l10n.commonUpdatedDate('$month/$day/${local.year}');
}
