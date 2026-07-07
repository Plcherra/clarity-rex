enum MemoryGroup {
  facts,
  preferences,
  people,
  places,
  goals,
  rules,
  events,
  other,
}

extension MemoryGroupLabel on MemoryGroup {
  /// English fallback for tests, search indexing, and backend category keys.
  /// UI should use `MemoryGroupL10n.localizedLabel`.
  String get label {
    switch (this) {
      case MemoryGroup.facts:
        return 'Facts';
      case MemoryGroup.preferences:
        return 'Preferences';
      case MemoryGroup.people:
        return 'People';
      case MemoryGroup.places:
        return 'Places';
      case MemoryGroup.goals:
        return 'Goals';
      case MemoryGroup.rules:
        return 'Rules';
      case MemoryGroup.events:
        return 'Events';
      case MemoryGroup.other:
        return 'Other';
    }
  }
}

extension MemoryRecordLabel on String {
  String get memoryRecordLabel {
    final mapped = humanMemoryLabel(this);
    if (mapped != null) {
      return mapped;
    }

    return fallbackHumanLabel;
  }

  String get fallbackHumanLabel {
    final value = trim();
    if (value.isEmpty) {
      return '';
    }

    return value
        .replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (_) => ' ')
        .split(RegExp(r'[_\s-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          final lowered = part.toLowerCase();
          return lowered[0].toUpperCase() + lowered.substring(1);
        })
        .join(' ');
  }
}

String memoryActionTypeLabel(String value) {
  return _memoryActionTypeLabels[_normalLabelKey(value)] ??
      value.fallbackHumanLabel;
}

String memoryActionStatusLabel(String value) {
  return _memoryActionStatusLabels[_normalLabelKey(value)] ??
      value.fallbackHumanLabel;
}

String memoryRiskLevelLabel(String value) {
  return _riskLevelLabels[_normalLabelKey(value)] ?? value.fallbackHumanLabel;
}

String? humanMemoryLabel(String value) {
  final key = _normalLabelKey(value);
  return _memoryActionTypeLabels[key] ??
      _recordTypeLabels[key] ??
      _statusLabels[key] ??
      _riskLevelLabels[key];
}

MemoryGroup memoryGroupForTypeLabel(String value) {
  switch (_normalLabelKey(value)) {
    case 'fact':
    case 'identity':
    case 'facts':
      return MemoryGroup.facts;
    case 'preference':
    case 'preferences':
      return MemoryGroup.preferences;
    case 'people':
    case 'entity':
    case 'person':
    case 'people_places':
      return MemoryGroup.people;
    case 'place':
    case 'places':
      return MemoryGroup.places;
    case 'goal':
    case 'goals':
    case 'plan':
    case 'plan_milestone':
      return MemoryGroup.goals;
    case 'personal_rule':
    case 'rule':
      return MemoryGroup.rules;
    case 'event':
    case 'events':
    case 'entity_event':
    case 'recent':
      return MemoryGroup.events;
    default:
      return MemoryGroup.other;
  }
}

String memoryPreviewWithRecordType(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  final separator = trimmed.indexOf(':');
  if (separator <= 0) {
    return trimmed;
  }

  final prefix = trimmed.substring(0, separator).trim();
  final label = _memoryActionTypeLabels[_normalLabelKey(prefix)];
  if (label == null) {
    return trimmed;
  }

  final rest = trimmed.substring(separator + 1).trimLeft();
  if (rest.isEmpty) {
    return label;
  }
  return '$label: $rest';
}

String normalMemoryLabelKey(String value) {
  return _normalLabelKey(value);
}

String _normalLabelKey(String value) {
  return value
      .trim()
      .replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (_) => '_')
      .replaceAll(RegExp(r'[\s-]+'), '_')
      .toLowerCase();
}

const _memoryActionTypeLabels = {
  'long_term_memory': 'Memory note',
  'memory_update': 'Memory update',
  'entity': 'Person / place',
  'entity_event': 'Related event',
  'personal_rule': 'Rule',
  'plan': 'Plan',
  'plan_milestone': 'Milestone',
  'save_plan': 'Save plan',
  'save_plan_milestone': 'Save milestone',
  'update_plan': 'Update plan',
  'update_plan_milestone': 'Update milestone',
  'save_entity_event': 'Save related note',
  'save_memory': 'Save memory',
  'memory': 'Memory note',
  'delete': 'Delete permanently',
  'delete_record': 'Delete permanently',
  'correction': 'Correction',
  'archive': 'Archive',
  'merge': 'Merge',
  'update_transaction': 'Recategorize transaction',
  'bulk_update_transaction_category': 'Recategorize transactions',
  'create_transaction': 'Add transaction',
  'delete_transaction': 'Delete transaction',
  'create_budget': 'Create budget',
  'update_budget': 'Update budget',
  'delete_budget': 'Delete budget',
  'create_category': 'Create category',
  'update_category': 'Update category',
  'delete_category': 'Delete category',
  'create_account': 'Create account',
  'update_account': 'Update account',
  'delete_account': 'Delete account',
  'delete_import_batch': 'Delete import batch',
};

const _recordTypeLabels = {
  'fact': 'Fact',
  'preference': 'Preference',
  'event': 'Event',
  'other': 'Other',
  'gentle_direct': 'Gentle reminder',
  'checkpoint': 'Checkpoint',
};

const _memoryActionStatusLabels = {
  'approved': 'Approved',
  'applied': 'Saved',
  'rejected': 'Rejected',
  'failed': 'Needs attention',
  'skipped': 'Skipped',
};

const _statusLabels = {
  ..._memoryActionStatusLabels,
  'active': 'Active',
  'inactive': 'Inactive',
  'open': 'Open',
  'completed': 'Completed',
  'resolved': 'Resolved',
  'dismissed': 'Dismissed',
  'archived': 'Archived',
};

const _riskLevelLabels = {
  'low': 'Low risk',
  'medium': 'Medium risk',
  'high': 'High risk',
  'critical': 'Critical risk',
  'info': 'Info',
};
