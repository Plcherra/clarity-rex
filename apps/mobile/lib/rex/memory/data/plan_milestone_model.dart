import 'package:clarity/rex/memory/data/memory_json_parsing.dart';

class PlanMilestoneMemoryItem {
  const PlanMilestoneMemoryItem({
    required this.id,
    required this.planId,
    required this.title,
    required this.description,
    required this.milestoneType,
    required this.priority,
    required this.status,
    required this.active,
    this.targetDate,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory PlanMilestoneMemoryItem.fromJson(Map<String, dynamic> json) {
    return PlanMilestoneMemoryItem(
      id: memoryJsonString(json['id']) ?? '',
      planId: memoryJsonString(json['plan_id']) ?? '',
      title: memoryJsonString(json['title']) ?? 'Milestone',
      description: memoryJsonString(json['description']),
      milestoneType: memoryJsonString(json['milestone_type']) ?? 'checkpoint',
      priority: memoryJsonInt(json['priority']) ?? 3,
      status: memoryJsonString(json['status']) ?? 'open',
      active: memoryJsonBool(json['active']) ?? true,
      targetDate: memoryJsonDateTime(json['target_date']),
      completedAt: memoryJsonDateTime(json['completed_at']),
      createdAt: memoryJsonDateTime(json['created_at']),
      updatedAt: memoryJsonDateTime(json['updated_at']),
    );
  }

  final String id;
  final String planId;
  final String title;
  final String? description;
  final String milestoneType;
  final int priority;
  final String status;
  final bool active;
  final DateTime? targetDate;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get previewLabel {
    final headline = title.trim();
    if (headline.isNotEmpty) {
      return headline;
    }
    return description?.trim() ?? '';
  }
}
