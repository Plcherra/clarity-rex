enum MemoryGroup {
  identity,
  preferences,
  peoplePlaces,
  plans,
  rules,
  recent,
  other,
}

extension MemoryGroupLabel on MemoryGroup {
  String get label {
    switch (this) {
      case MemoryGroup.identity:
        return 'Identity';
      case MemoryGroup.preferences:
        return 'Preferences';
      case MemoryGroup.peoplePlaces:
        return 'People & places';
      case MemoryGroup.plans:
        return 'Plans';
      case MemoryGroup.rules:
        return 'Rules';
      case MemoryGroup.recent:
        return 'Recent';
      case MemoryGroup.other:
        return 'Other memories';
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

String memoryCandidateTypeLabel(String value) {
  return _candidateTypeLabels[_normalLabelKey(value)] ??
      value.fallbackHumanLabel;
}

String memoryCandidateStatusLabel(String value) {
  return _candidateStatusLabels[_normalLabelKey(value)] ??
      value.fallbackHumanLabel;
}

String memoryRiskLevelLabel(String value) {
  return _riskLevelLabels[_normalLabelKey(value)] ?? value.fallbackHumanLabel;
}

String? humanMemoryLabel(String value) {
  final key = _normalLabelKey(value);
  return _candidateTypeLabels[key] ??
      _recordTypeLabels[key] ??
      _statusLabels[key] ??
      _riskLevelLabels[key];
}

MemoryGroup memoryGroupForTypeLabel(String value) {
  switch (_normalLabelKey(value)) {
    case 'fact':
    case 'identity':
      return MemoryGroup.identity;
    case 'preference':
    case 'preferences':
      return MemoryGroup.preferences;
    case 'entity':
    case 'person':
    case 'people':
    case 'place':
    case 'people_places':
      return MemoryGroup.peoplePlaces;
    case 'plan':
    case 'plan_milestone':
    case 'commitment':
      return MemoryGroup.plans;
    case 'personal_rule':
    case 'rule':
      return MemoryGroup.rules;
    case 'event':
    case 'entity_event':
    case 'recent':
      return MemoryGroup.recent;
    default:
      return MemoryGroup.other;
  }
}

String memoryPreviewWithHumanType(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  final separator = trimmed.indexOf(':');
  if (separator <= 0) {
    return trimmed;
  }

  final prefix = trimmed.substring(0, separator).trim();
  final label = _candidateTypeLabels[_normalLabelKey(prefix)];
  if (label == null) {
    return trimmed;
  }

  final rest = trimmed.substring(separator + 1).trimLeft();
  if (rest.isEmpty) {
    return label;
  }
  return '$label: $rest';
}

String? correctionPreviewLabel({
  required String? oldValue,
  required String? newValue,
  required String? targetHint,
}) {
  final oldText = oldValue?.trim();
  final newText = newValue?.trim();
  final targetText = targetHint?.trim();
  if (oldText != null &&
      oldText.isNotEmpty &&
      newText != null &&
      newText.isNotEmpty) {
    return 'Correction: replace "$oldText" with "$newText"';
  }
  if (targetText != null &&
      targetText.isNotEmpty &&
      newText != null &&
      newText.isNotEmpty) {
    return 'Correction: change "$targetText" to "$newText"';
  }
  if (targetText != null && targetText.isNotEmpty) {
    return 'Correction: review $targetText';
  }
  return null;
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

const _candidateTypeLabels = {
  'long_term_memory': 'Memory',
  'memory_update': 'Memory update',
  'entity': 'Person / place',
  'entity_event': 'Related event',
  'personal_rule': 'Rule',
  'plan': 'Plan',
  'plan_milestone': 'Milestone',
  'commitment': 'Commitment',
  'correction': 'Correction',
  'archive': 'Archive',
  'merge': 'Merge',
};

const _recordTypeLabels = {
  'fact': 'Fact',
  'preference': 'Preference',
  'event': 'Event',
  'other': 'Other',
  'gentle_direct': 'Gentle reminder',
  'checkpoint': 'Checkpoint',
};

const _candidateStatusLabels = {
  'pending': 'Needs review',
  'approved': 'Approved',
  'applied': 'Saved',
  'rejected': 'Rejected',
  'failed': 'Needs attention',
  'skipped': 'Skipped',
};

const _statusLabels = {
  ..._candidateStatusLabels,
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
