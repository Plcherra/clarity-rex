import 'package:clarity/rex/memory/data/memory_json_parsing.dart';
import 'package:clarity/rex/memory/data/memory_labels.dart';

class EntityMemoryItem {
  const EntityMemoryItem({
    required this.id,
    required this.entityType,
    required this.displayName,
    required this.relationship,
    required this.summary,
    required this.aliases,
    required this.importance,
    required this.status,
    required this.active,
    required this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  factory EntityMemoryItem.fromJson(Map<String, dynamic> json) {
    return EntityMemoryItem(
      id: memoryJsonString(json['id']) ?? '',
      entityType: memoryJsonString(json['entity_type']) ?? 'other',
      displayName: memoryJsonString(json['display_name']) ?? 'Saved item',
      relationship: memoryJsonString(json['relationship']),
      summary: memoryJsonString(json['summary']),
      aliases: memoryJsonStringList(json['aliases']),
      importance: memoryJsonInt(json['importance']) ?? 3,
      status: memoryJsonString(json['status']) ?? 'active',
      active: memoryJsonBool(json['active']) ?? true,
      metadata: memoryJsonMap(json['metadata']),
      createdAt: memoryJsonDateTime(json['created_at']),
      updatedAt: memoryJsonDateTime(json['updated_at']),
    );
  }

  final String id;
  final String entityType;
  final String displayName;
  final String? relationship;
  final String? summary;
  final List<String> aliases;
  final int importance;
  final String status;
  final bool active;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPerson => entityType == 'person';

  bool get isPlace => entityType == 'place';

  MemoryGroup get memoryGroup {
    switch (entityType) {
      case 'person':
        return MemoryGroup.people;
      case 'place':
        return MemoryGroup.places;
      default:
        return MemoryGroup.other;
    }
  }

  Map<String, dynamic> get attributes {
    final value = metadata['attributes'];
    return value is Map<String, dynamic> ? value : const <String, dynamic>{};
  }

  String? get location => memoryAttributeText(attributes['location']);

  String? get notes => memoryAttributeText(attributes['notes']);

  List<String> get sourceMemoryIds {
    final ids = <String>{};
    ids.addAll(memoryFlexibleStringList(metadata['source_memory_ids']));
    final attributeSources = metadata['attribute_source_memory_ids'];
    if (attributeSources is Map) {
      for (final value in attributeSources.values) {
        ids.addAll(memoryFlexibleStringList(value));
      }
    }
    return ids.toList(growable: false);
  }

  List<String> get searchableFields {
    return [
      displayName,
      ?relationship,
      ?summary,
      ?location,
      ?notes,
      'Importance $importance',
      status,
      entityType.memoryRecordLabel,
    ];
  }
}
