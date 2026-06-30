import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/memory/data/memory_labels.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';

/// Canonical backend category keys for flat memory create flows.
const memoryCreateCategoryKeys = [  'People',
  'Events',
  'Places',
  'Goals',
  'Preferences',
  'Facts',
  'Other',
];

extension MemoryGroupL10n on MemoryGroup {
  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case MemoryGroup.facts:
        return l10n.memoryGroupFacts;
      case MemoryGroup.preferences:
        return l10n.memoryGroupPreferences;
      case MemoryGroup.people:
        return l10n.memoryGroupPeople;
      case MemoryGroup.places:
        return l10n.memoryGroupPlaces;
      case MemoryGroup.goals:
        return l10n.memoryGroupGoals;
      case MemoryGroup.rules:
        return l10n.memoryGroupRules;
      case MemoryGroup.events:
        return l10n.memoryGroupEvents;
      case MemoryGroup.other:
        return l10n.memoryGroupOther;
    }
  }
}

extension MemoryTypeL10n on MemoryType {
  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case MemoryType.fact:
        return l10n.memoryTypeFact;
      case MemoryType.preference:
        return l10n.memoryTypePreference;
      case MemoryType.event:
        return l10n.memoryTypeEvent;
      case MemoryType.other:
        return l10n.memoryTypeOther;
    }
  }
}

String entityTypeLabel(AppLocalizations l10n, String entityType) {
  switch (entityType) {
    case 'person':
      return l10n.commonPerson;
    case 'place':
      return l10n.memoryEntityTypePlace;
    case 'organization':
      return l10n.memoryEntityTypeOrganization;
    default:
      return localizedMemoryRecordLabel(l10n, entityType);
  }
}

String localizedMemoryRecordLabel(AppLocalizations l10n, String value) {
  switch (normalMemoryLabelKey(value)) {
    case 'long_term_memory':
      return l10n.memoryRecordLongTermMemory;
    case 'memory_update':
      return l10n.memoryRecordMemoryUpdate;
    case 'entity':
      return l10n.memoryRecordEntity;
    case 'entity_event':
      return l10n.memoryRecordEntityEvent;
    case 'personal_rule':
      return l10n.memoryRecordPersonalRule;
    case 'plan':
      return l10n.memoryRecordPlan;
    case 'plan_milestone':
      return l10n.memoryRecordPlanMilestone;
    case 'commitment':
      return l10n.memoryRecordCommitment;
    case 'correction':
      return l10n.memoryRecordCorrection;
    case 'archive':
      return l10n.memoryRecordArchive;
    case 'merge':
      return l10n.memoryRecordMerge;
    case 'fact':
      return l10n.memoryTypeFact;
    case 'preference':
      return l10n.memoryTypePreference;
    case 'event':
      return l10n.memoryTypeEvent;
    case 'other':
      return l10n.memoryTypeOther;
    case 'gentle_direct':
      return l10n.memoryRecordGentleDirect;
    case 'checkpoint':
      return l10n.memoryRecordCheckpoint;
    case 'approved':
      return l10n.memoryRecordApproved;
    case 'applied':
      return l10n.memoryRecordApplied;
    case 'rejected':
      return l10n.memoryRecordRejected;
    case 'failed':
      return l10n.memoryRecordFailed;
    case 'skipped':
      return l10n.memoryRecordSkipped;
    case 'active':
      return l10n.memoryRecordActive;
    case 'inactive':
      return l10n.memoryRecordInactive;
    case 'open':
      return l10n.memoryRecordOpen;
    case 'completed':
      return l10n.memoryRecordCompleted;
    case 'resolved':
      return l10n.memoryRecordResolved;
    case 'dismissed':
      return l10n.memoryRecordDismissed;
    case 'archived':
      return l10n.memoryRecordArchived;
    case 'low':
      return l10n.memoryRecordLowRisk;
    case 'medium':
      return l10n.memoryRecordMediumRisk;
    case 'high':
      return l10n.memoryRecordHighRisk;
    case 'critical':
      return l10n.memoryRecordCriticalRisk;
    case 'info':
      return l10n.memoryRecordInfo;
    case 'note':
      return l10n.memoryRecordEventNote;
    case 'interaction':
      return l10n.memoryRecordEventInteraction;
    case 'relationship_update':
      return l10n.memoryRecordEventRelationshipUpdate;
    case 'conflict':
      return l10n.memoryRecordEventConflict;
    case 'milestone':
      return l10n.memoryRecordEventMilestone;
    case 'project':
      return l10n.memoryRecordProject;
    case 'task':
      return l10n.memoryRecordTask;
    default:
      return value.memoryRecordLabel;
  }
}

String memoryCreateCategoryLabel(AppLocalizations l10n, String canonicalCategory) {
  switch (canonicalCategory) {
    case 'People':
      return l10n.memoryGroupPeople;
    case 'Events':
      return l10n.memoryGroupEvents;
    case 'Places':
      return l10n.memoryGroupPlaces;
    case 'Goals':
      return l10n.memoryGroupGoals;
    case 'Preferences':
      return l10n.memoryGroupPreferences;
    case 'Facts':
      return l10n.memoryGroupFacts;
    case 'Other':
      return l10n.memoryGroupOther;
    default:
      return canonicalCategory.memoryRecordLabel;
  }
}
