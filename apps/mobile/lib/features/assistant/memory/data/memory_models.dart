import 'package:freezed_annotation/freezed_annotation.dart';

part 'memory_models.freezed.dart';
part 'memory_models.g.dart';

enum MemoryType { fact, preference, event, other }

enum MemoryLayer { longTerm, people, rules, plans, commitments }

enum MemoryReviewMode { saved, pending }

enum MemoryGroup {
  identity,
  preferences,
  peoplePlaces,
  plans,
  rules,
  recent,
  other,
}

@freezed
abstract class MemoryItem with _$MemoryItem {
  const factory MemoryItem({
    required String id,
    @JsonKey(name: 'memory_type', unknownEnumValue: MemoryType.other)
    required MemoryType memoryType,
    required String content,
    @JsonKey(name: 'source_conversation_id') String? sourceConversationId,
    @JsonKey(name: 'source_message_id') String? sourceMessageId,
    required int importance,
    required bool active,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(name: 'last_accessed_at') DateTime? lastAccessedAt,
  }) = _MemoryItem;

  factory MemoryItem.fromJson(Map<String, dynamic> json) =>
      _$MemoryItemFromJson(json);
}

extension MemoryTypeLabel on MemoryType {
  String get label {
    switch (this) {
      case MemoryType.fact:
        return 'Fact';
      case MemoryType.preference:
        return 'Preference';
      case MemoryType.event:
        return 'Event';
      case MemoryType.other:
        return 'Other memory';
    }
  }

  String get pluralLabel {
    switch (this) {
      case MemoryType.fact:
        return 'Facts';
      case MemoryType.preference:
        return 'Preferences';
      case MemoryType.event:
        return 'Events';
      case MemoryType.other:
        return 'Other memories';
    }
  }

  String get apiValue => name;

  MemoryGroup get memoryGroup {
    switch (this) {
      case MemoryType.fact:
        return MemoryGroup.identity;
      case MemoryType.preference:
        return MemoryGroup.preferences;
      case MemoryType.event:
        return MemoryGroup.recent;
      case MemoryType.other:
        return MemoryGroup.other;
    }
  }
}

extension MemoryLayerLabel on MemoryLayer {
  String get label {
    switch (this) {
      case MemoryLayer.longTerm:
        return 'Notes';
      case MemoryLayer.people:
        return 'People';
      case MemoryLayer.rules:
        return 'Rules';
      case MemoryLayer.plans:
        return 'Plans';
      case MemoryLayer.commitments:
        return 'Commitments';
    }
  }
}

extension MemoryReviewModeLabel on MemoryReviewMode {
  String get label {
    switch (this) {
      case MemoryReviewMode.saved:
        return 'Saved';
      case MemoryReviewMode.pending:
        return 'Pending review';
    }
  }
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

class PendingMemoryCandidateItem {
  const PendingMemoryCandidateItem({
    required this.id,
    required this.candidateType,
    required this.status,
    required this.riskLevel,
    required this.preview,
    required this.reason,
    required this.expectedAction,
    required this.payload,
    required this.requiresExplicitConfirmation,
    required this.correctionOldValue,
    required this.correctionNewValue,
    required this.correctionTargetHint,
    required this.sourceConversationId,
    required this.sourceMessageId,
    required this.verificationPassed,
    required this.verificationMessage,
    required this.remainingConflictCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PendingMemoryCandidateItem.fromJson(Map<String, dynamic> json) {
    final verification = _map(json['verification']);
    final correctionValues = _candidateCorrectionValues(json);
    return PendingMemoryCandidateItem(
      id: _string(json['id']) ?? '',
      candidateType: _string(json['candidate_type']) ?? 'memory_update',
      status: _string(json['status']) ?? 'pending',
      riskLevel: _string(json['risk_level']) ?? 'medium',
      preview: _string(json['preview']) ?? 'Pending memory change',
      reason: _string(json['reason']) ?? _string(json['rationale']),
      expectedAction:
          _string(json['expected_action']) ??
          'Apply pending memory change after confirmation',
      payload: _map(json['payload']),
      requiresExplicitConfirmation:
          _bool(verification['requires_explicit_confirmation']) ??
          _bool(_map(json['payload'])['requires_explicit_confirmation']) ??
          false,
      correctionOldValue: correctionValues.oldValue,
      correctionNewValue: correctionValues.newValue,
      correctionTargetHint: correctionValues.targetHint,
      sourceConversationId: _string(json['source_conversation_id']),
      sourceMessageId: _string(json['source_message_id']),
      verificationPassed: _bool(verification['passed']),
      verificationMessage: _string(verification['message']),
      remainingConflictCount:
          _int(verification['remaining_conflict_count']) ?? 0,
      createdAt: _dateTime(json['created_at']),
      updatedAt: _dateTime(json['updated_at']),
    );
  }

  final String id;
  final String candidateType;
  final String status;
  final String riskLevel;
  final String preview;
  final String? reason;
  final String expectedAction;
  final Map<String, dynamic> payload;
  final bool requiresExplicitConfirmation;
  final String? correctionOldValue;
  final String? correctionNewValue;
  final String? correctionTargetHint;
  final String? sourceConversationId;
  final String? sourceMessageId;
  final bool? verificationPassed;
  final String? verificationMessage;
  final int remainingConflictCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get candidateTypeLabel => memoryCandidateTypeLabel(candidateType);
  String get statusLabel => memoryCandidateStatusLabel(status);
  String get riskLabel => memoryRiskLevelLabel(riskLevel);
  String get previewLabel {
    final correction = correctionPreviewLabel(
      oldValue: correctionOldValue,
      newValue: correctionNewValue,
      targetHint: correctionTargetHint,
    );
    return correction ?? memoryPreviewWithHumanType(preview);
  }

  String get expectedActionLabel => expectedAction.memoryRecordLabel;
  String get editableProposal {
    final payloadText = _firstPayloadText(
      payload,
      _candidatePrimaryTextKeys(candidateType),
    );
    if (payloadText != null) {
      return payloadText;
    }

    final previewText = previewLabel.trim();
    final separator = previewText.indexOf(':');
    if (separator > 0 && separator + 1 < previewText.length) {
      return previewText.substring(separator + 1).trim();
    }
    return previewText;
  }

  bool get isHighRisk => riskLevel == 'high';
  bool get isPending => status == 'pending';
  bool get isApplied => status == 'applied';
  bool get isRejected => status == 'rejected';
  bool get isFailed => status == 'failed';
  bool get isSkipped => status == 'skipped';
  bool get isCorrection => candidateType == 'correction';
  String? get reasonLabel {
    final text = reason?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? get sourceLabel {
    final conversation = sourceConversationId?.trim();
    final message = sourceMessageId?.trim();
    if ((conversation == null || conversation.isEmpty) &&
        (message == null || message.isEmpty)) {
      return null;
    }
    if (conversation != null && conversation.isNotEmpty) {
      return 'From recent chat';
    }
    return 'From recent message';
  }

  String get statusDetail {
    if (isApplied) {
      return 'Saved to Rex Memory.';
    }
    if (isRejected) {
      return 'Rejected. Rex will not save this memory.';
    }
    if (isFailed) {
      return 'Could not save this memory. Review it before trying again.';
    }
    if (isSkipped) {
      return 'Skipped. This memory was not changed.';
    }
    if (isHighRisk || requiresExplicitConfirmation) {
      if (isCorrection) {
        return 'Rex will wait for your approval before changing saved memory.';
      }
      return 'Review carefully before confirming this memory.';
    }
    return 'Approve only if Rex should remember this.';
  }
}

class PersonMemoryItem {
  const PersonMemoryItem({
    required this.id,
    required this.displayName,
    required this.relationship,
    required this.summary,
    required this.aliases,
    required this.importance,
    required this.status,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  factory PersonMemoryItem.fromJson(Map<String, dynamic> json) {
    return PersonMemoryItem(
      id: _string(json['id']) ?? '',
      displayName: _string(json['display_name']) ?? 'Person',
      relationship: _string(json['relationship']),
      summary: _string(json['summary']),
      aliases: _stringList(json['aliases']),
      importance: _int(json['importance']) ?? 3,
      status: _string(json['status']) ?? 'active',
      active: _bool(json['active']) ?? true,
      createdAt: _dateTime(json['created_at']),
      updatedAt: _dateTime(json['updated_at']),
    );
  }

  final String id;
  final String displayName;
  final String? relationship;
  final String? summary;
  final List<String> aliases;
  final int importance;
  final String status;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class RuleMemoryItem {
  const RuleMemoryItem({
    required this.id,
    required this.ruleType,
    required this.title,
    required this.ruleText,
    required this.triggerKeywords,
    required this.priority,
    required this.status,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  factory RuleMemoryItem.fromJson(Map<String, dynamic> json) {
    return RuleMemoryItem(
      id: _string(json['id']) ?? '',
      ruleType: _string(json['rule_type']) ?? 'other',
      title: _string(json['title']) ?? 'Rule',
      ruleText: _string(json['rule_text']) ?? '',
      triggerKeywords: _stringList(json['trigger_keywords']),
      priority: _int(json['priority']) ?? 3,
      status: _string(json['status']) ?? 'active',
      active: _bool(json['active']) ?? true,
      createdAt: _dateTime(json['created_at']),
      updatedAt: _dateTime(json['updated_at']),
    );
  }

  final String id;
  final String ruleType;
  final String title;
  final String ruleText;
  final List<String> triggerKeywords;
  final int priority;
  final String status;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class PlanMemoryItem {
  const PlanMemoryItem({
    required this.id,
    required this.planType,
    required this.title,
    required this.description,
    required this.desiredOutcome,
    required this.priority,
    required this.status,
    required this.active,
    required this.targetDate,
    required this.primaryEntityId,
    this.createdAt,
    this.updatedAt,
  });

  factory PlanMemoryItem.fromJson(Map<String, dynamic> json) {
    return PlanMemoryItem(
      id: _string(json['id']) ?? '',
      planType: _string(json['plan_type']) ?? 'other',
      title: _string(json['title']) ?? 'Plan',
      description: _string(json['description']),
      desiredOutcome: _string(json['desired_outcome']),
      priority: _int(json['priority']) ?? 3,
      status: _string(json['status']) ?? 'active',
      active: _bool(json['active']) ?? true,
      targetDate: _dateTime(json['target_date']),
      primaryEntityId: _string(json['primary_entity_id']),
      createdAt: _dateTime(json['created_at']),
      updatedAt: _dateTime(json['updated_at']),
    );
  }

  final String id;
  final String planType;
  final String title;
  final String? description;
  final String? desiredOutcome;
  final int priority;
  final String status;
  final bool active;
  final DateTime? targetDate;
  final String? primaryEntityId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class CommitmentMemoryItem {
  const CommitmentMemoryItem({
    required this.id,
    required this.commitmentType,
    required this.title,
    required this.commitmentText,
    required this.priority,
    required this.status,
    required this.active,
    required this.dueAt,
    required this.planId,
    required this.entityId,
    this.createdAt,
    this.updatedAt,
  });

  factory CommitmentMemoryItem.fromJson(Map<String, dynamic> json) {
    return CommitmentMemoryItem(
      id: _string(json['id']) ?? '',
      commitmentType: _string(json['commitment_type']) ?? 'other',
      title: _string(json['title']) ?? 'Commitment',
      commitmentText: _string(json['commitment_text']) ?? '',
      priority: _int(json['priority']) ?? 3,
      status: _string(json['status']) ?? 'open',
      active: _bool(json['active']) ?? true,
      dueAt: _dateTime(json['due_at']),
      planId: _string(json['plan_id']),
      entityId: _string(json['entity_id']),
      createdAt: _dateTime(json['created_at']),
      updatedAt: _dateTime(json['updated_at']),
    );
  }

  final String id;
  final String commitmentType;
  final String title;
  final String commitmentText;
  final int priority;
  final String status;
  final bool active;
  final DateTime? dueAt;
  final String? planId;
  final String? entityId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
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

Map<String, dynamic> editedMemoryCandidatePayload(
  PendingMemoryCandidateItem candidate,
  String proposal,
) {
  final payload = Map<String, dynamic>.from(candidate.payload);
  final key = _firstEditablePayloadKey(candidate);
  payload[key] = proposal.trim();
  return payload;
}

String _firstEditablePayloadKey(PendingMemoryCandidateItem candidate) {
  for (final key in _candidatePrimaryTextKeys(candidate.candidateType)) {
    final value = candidate.payload[key];
    if (value is String && value.trim().isNotEmpty) {
      return key;
    }
  }
  return _candidatePrimaryTextKeys(candidate.candidateType).first;
}

String? _firstPayloadText(Map<String, dynamic> payload, List<String> keys) {
  for (final key in keys) {
    final value = payload[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

List<String> _candidatePrimaryTextKeys(String candidateType) {
  switch (_normalLabelKey(candidateType)) {
    case 'entity':
      return const ['display_name', 'title', 'content'];
    case 'personal_rule':
      return const ['rule_text', 'title', 'content'];
    case 'commitment':
      return const ['commitment_text', 'title', 'content'];
    case 'correction':
      return const ['text', 'content'];
    case 'plan':
    case 'plan_milestone':
      return const ['title', 'description', 'content'];
    case 'entity_event':
      return const ['title', 'content', 'description'];
    default:
      return const ['content', 'title', 'new_value'];
  }
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

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

bool? _bool(Object? value) => value is bool ? value : null;

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList(growable: false);
}

Map<String, dynamic> _map(Object? value) {
  return value is Map<String, dynamic> ? value : const {};
}

typedef _CandidateCorrectionValues = ({
  String? oldValue,
  String? newValue,
  String? targetHint,
});

_CandidateCorrectionValues _candidateCorrectionValues(
  Map<String, dynamic> json,
) {
  final payloadPreview = _map(json['payload_preview']);
  final payload = _map(json['payload']);
  final previewIntent = _map(payloadPreview['intent']);
  final payloadIntent = _map(payload['intent']);
  return (
    oldValue:
        _string(json['old_value']) ??
        _string(previewIntent['old_value']) ??
        _string(payloadIntent['old_value']),
    newValue:
        _string(json['new_value']) ??
        _string(previewIntent['new_value']) ??
        _string(payloadIntent['new_value']),
    targetHint:
        _string(json['target_hint']) ??
        _string(previewIntent['target_hint']) ??
        _string(payloadIntent['target_hint']),
  );
}

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
