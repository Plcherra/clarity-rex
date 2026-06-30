import 'package:clarity/rex/memory/data/entity_memory_model.dart';
import 'package:clarity/rex/memory/data/memory_json_parsing.dart';

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
    return PersonMemoryItem.fromEntity(EntityMemoryItem.fromJson(json));
  }

  factory PersonMemoryItem.fromEntity(EntityMemoryItem entity) {
    return PersonMemoryItem(
      id: entity.id,
      displayName: entity.displayName,
      relationship: entity.relationship,
      summary: entity.summary,
      aliases: entity.aliases,
      importance: entity.importance,
      status: entity.status,
      active: entity.active,
      metadata: entity.metadata,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
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

  String? get fullName => memoryAttributeText(attributes['full_name']);

  String? get location => memoryAttributeText(attributes['location']);

  String? get birthday => memoryAttributeText(attributes['birthday']);

  String? get job => memoryAttributeText(attributes['job']);

  String? get workplace => memoryAttributeText(attributes['workplace']);

  String? get notes => memoryAttributeText(attributes['notes']);

  List<String> get importantDates {
    return memoryFlexibleStringList(
      attributes['important_dates'] ??
          attributes['importantDates'] ??
          metadata['important_dates'] ??
          metadata['importantDates'],
    );
  }

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

  List<String> get safeAliases {
    return aliases
        .where((alias) => !_isUnsafeAlias(alias))
        .toList(growable: false);
  }

  List<String> get searchableFields {
    return [
      displayName,
      ?relationship,
      ?summary,
      ?fullName,
      ?location,
      ?birthday,
      ?job,
      ?workplace,
      ?notes,
      ...importantDates,
      'Importance $importance',
      status,
    ];
  }
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
