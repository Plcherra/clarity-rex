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
    required this.metadata,
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
      metadata: _map(json['metadata']),
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
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> get attributes {
    final value = metadata['attributes'];
    return value is Map<String, dynamic> ? value : const <String, dynamic>{};
  }

  String? get fullName => _attributeText(attributes['full_name']);

  String? get location => _attributeText(attributes['location']);

  String? get birthday => _attributeText(attributes['birthday']);

  String? get job => _attributeText(attributes['job']);

  String? get workplace => _attributeText(attributes['workplace']);

  String? get notes => _attributeText(attributes['notes']);

  List<String> get importantDates {
    return _flexibleStringList(
      attributes['important_dates'] ??
          attributes['importantDates'] ??
          metadata['important_dates'] ??
          metadata['importantDates'],
    );
  }

  List<String> get safeAliases {
    return aliases
        .where((alias) => !_isUnsafeAlias(alias))
        .toList(growable: false);
  }

  List<String> get searchableFields {
    return [
      displayName,
      if (relationship != null) relationship!,
      if (summary != null) summary!,
      if (fullName != null) fullName!,
      if (location != null) location!,
      if (birthday != null) birthday!,
      if (job != null) job!,
      if (workplace != null) workplace!,
      if (notes != null) notes!,
      ...importantDates,
      'Importance $importance',
      status,
    ];
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

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList(growable: false);
}

List<String> _flexibleStringList(Object? value) {
  if (value is List) {
    return value
        .map(_attributeText)
        .whereType<String>()
        .toList(growable: false);
  }
  if (value is Map) {
    return value.entries
        .map((entry) {
          final label = _attributeText(entry.key);
          final text = _attributeText(entry.value);
          if (label == null) {
            return text;
          }
          if (text == null) {
            return label;
          }
          return '$label: $text';
        })
        .whereType<String>()
        .toList(growable: false);
  }
  final text = _attributeText(value);
  return text == null ? const [] : [text];
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
}

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String? _attributeText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool _isUnsafeAlias(String value) {
  final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  final tokens = normalized
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toSet();
  return tokens.intersection(_unsafeAliasTerms).isNotEmpty ||
      normalized.contains('bank of america');
}

const _unsafeAliasTerms = {
  'account',
  'bank',
  'checking',
  'credit',
  'debit',
  'deposit',
  'deposits',
  'merchant',
  'payroll',
  'zelle',
};
