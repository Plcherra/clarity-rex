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

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
