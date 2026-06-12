import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:clarity/rex/memory/data/memory_labels.dart';

export 'package:clarity/rex/memory/data/memory_labels.dart';
export 'package:clarity/rex/memory/data/person_memory_model.dart';
export 'package:clarity/rex/memory/data/rule_memory_model.dart';

part 'memory_models.freezed.dart';
part 'memory_models.g.dart';

enum MemoryType { fact, preference, event, other }

enum MemoryLayer { longTerm, people, rules, plans, commitments }

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
        return 'Other';
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

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
