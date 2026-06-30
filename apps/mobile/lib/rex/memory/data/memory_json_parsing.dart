String? memoryJsonString(Object? value) => value is String ? value : null;

int? memoryJsonInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

bool? memoryJsonBool(Object? value) => value is bool ? value : null;

DateTime? memoryJsonDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

List<String> memoryJsonStringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList(growable: false);
}

Map<String, dynamic> memoryJsonMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
}

String? memoryAttributeText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

List<String> memoryFlexibleStringList(Object? value) {
  if (value is List) {
    return value
        .map(memoryAttributeText)
        .whereType<String>()
        .toList(growable: false);
  }
  if (value is Map) {
    return value.entries
        .map((entry) {
          final label = memoryAttributeText(entry.key);
          final text = memoryAttributeText(entry.value);
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
  final text = memoryAttributeText(value);
  return text == null ? const [] : [text];
}
