import 'package:clarity/rex/memory/data/memory_json_parsing.dart';

class EntityEventItem {
  const EntityEventItem({
    required this.id,
    required this.entityId,
    required this.eventType,
    required this.title,
    required this.content,
    required this.importance,
    required this.active,
    this.occurredAt,
    this.createdAt,
    this.updatedAt,
  });

  factory EntityEventItem.fromJson(Map<String, dynamic> json) {
    return EntityEventItem(
      id: memoryJsonString(json['id']) ?? '',
      entityId: memoryJsonString(json['entity_id']) ?? '',
      eventType: memoryJsonString(json['event_type']) ?? 'note',
      title: memoryJsonString(json['title']),
      content: memoryJsonString(json['content']) ?? '',
      importance: memoryJsonInt(json['importance']) ?? 3,
      active: memoryJsonBool(json['active']) ?? true,
      occurredAt: memoryJsonDateTime(json['occurred_at']),
      createdAt: memoryJsonDateTime(json['created_at']),
      updatedAt: memoryJsonDateTime(json['updated_at']),
    );
  }

  final String id;
  final String entityId;
  final String eventType;
  final String? title;
  final String content;
  final int importance;
  final bool active;
  final DateTime? occurredAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get previewLabel {
    final headline = title?.trim();
    if (headline != null && headline.isNotEmpty) {
      return headline;
    }
    return content.trim();
  }
}
