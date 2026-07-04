import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:clarity/rex/memory/data/memory_json_parsing.dart';
import 'package:clarity/rex/memory/data/memory_labels.dart';

export 'package:clarity/rex/memory/data/entity_event_model.dart';
export 'package:clarity/rex/memory/data/entity_memory_model.dart';
export 'package:clarity/rex/memory/data/memory_labels.dart';
export 'package:clarity/rex/memory/data/person_memory_model.dart';
export 'package:clarity/rex/memory/data/plan_milestone_model.dart';
export 'package:clarity/rex/memory/data/rule_memory_model.dart';
export 'package:clarity/rex/memory/data/structured_memory_kind.dart';

part 'memory_models.freezed.dart';
part 'memory_models.g.dart';

enum MemoryType { fact, preference, event, other }

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
    @Default(<String, dynamic>{}) Map<String, dynamic> metadata,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(name: 'last_accessed_at') DateTime? lastAccessedAt,
  }) = _MemoryItem;

  factory MemoryItem.fromJson(Map<String, dynamic> json) =>
      _$MemoryItemFromJson(json);
}

extension MemoryTypeLabel on MemoryType {
  /// English fallback for tests and search indexing.
  /// UI should use `MemoryTypeL10n.localizedLabel`.
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
        return MemoryGroup.facts;
      case MemoryType.preference:
        return MemoryGroup.preferences;
      case MemoryType.event:
        return MemoryGroup.events;
      case MemoryType.other:
        return MemoryGroup.other;
    }
  }
}

extension MemoryItemCategory on MemoryItem {
  String get categoryLabel => memoryGroup.label;

  MemoryGroup get memoryGroup {
    final category = _memoryCategoryFromMetadata(metadata);
    if (category != null) {
      return category;
    }
    return memoryType.memoryGroup;
  }
}

MemoryGroup? _memoryCategoryFromMetadata(Map<String, dynamic> metadata) {
  final rawValue = metadata['memory_category'] ?? metadata['category'];
  if (rawValue is! String) {
    return null;
  }
  switch (normalMemoryLabelKey(rawValue)) {
    case 'people':
      return MemoryGroup.people;
    case 'events':
      return MemoryGroup.events;
    case 'places':
      return MemoryGroup.places;
    case 'goals':
      return MemoryGroup.goals;
    case 'preferences':
      return MemoryGroup.preferences;
    case 'facts':
      return MemoryGroup.facts;
    case 'other':
      return MemoryGroup.other;
    default:
      return null;
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
      id: memoryJsonString(json['id']) ?? '',
      planType: memoryJsonString(json['plan_type']) ?? 'other',
      title: memoryJsonString(json['title']) ?? 'Plan',
      description: memoryJsonString(json['description']),
      desiredOutcome: memoryJsonString(json['desired_outcome']),
      priority: memoryJsonInt(json['priority']) ?? 3,
      status: memoryJsonString(json['status']) ?? 'active',
      active: memoryJsonBool(json['active']) ?? true,
      targetDate: memoryJsonDateTime(json['target_date']),
      primaryEntityId: memoryJsonString(json['primary_entity_id']),
      createdAt: memoryJsonDateTime(json['created_at']),
      updatedAt: memoryJsonDateTime(json['updated_at']),
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
