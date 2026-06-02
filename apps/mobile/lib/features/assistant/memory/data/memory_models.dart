import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:clarity/features/assistant/memory/data/memory_labels.dart';

export 'package:clarity/features/assistant/memory/data/memory_labels.dart';
export 'package:clarity/features/assistant/memory/data/person_memory_model.dart';
export 'package:clarity/features/assistant/memory/data/rule_memory_model.dart';

part 'memory_models.freezed.dart';
part 'memory_models.g.dart';

enum MemoryType { fact, preference, event, other }

enum MemoryLayer { longTerm, people, rules, plans, commitments }

enum MemoryReviewMode { saved, pending }

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
      reason:
          _string(json['review_reason']) ??
          _string(json['reason']) ??
          _string(json['rationale']),
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
  switch (normalMemoryLabelKey(candidateType)) {
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
