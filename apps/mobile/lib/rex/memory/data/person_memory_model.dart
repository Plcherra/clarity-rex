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
