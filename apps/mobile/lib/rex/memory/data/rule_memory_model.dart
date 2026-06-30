import 'package:clarity/rex/memory/data/memory_json_parsing.dart';

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
      id: memoryJsonString(json['id']) ?? '',
      ruleType: memoryJsonString(json['rule_type']) ?? 'other',
      title: memoryJsonString(json['title']) ?? 'Rule',
      ruleText: memoryJsonString(json['rule_text']) ?? '',
      triggerKeywords: memoryJsonStringList(json['trigger_keywords']),
      priority: memoryJsonInt(json['priority']) ?? 3,
      status: memoryJsonString(json['status']) ?? 'active',
      active: memoryJsonBool(json['active']) ?? true,
      createdAt: memoryJsonDateTime(json['created_at']),
      updatedAt: memoryJsonDateTime(json['updated_at']),
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
