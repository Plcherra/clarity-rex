final class ProfileRecord {
  const ProfileRecord({
    required this.id,
    this.email,
    this.fullName,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProfileRecord.fromJson(Map<String, dynamic> json) {
    return ProfileRecord(
      id: _string(json, 'id'),
      email: _nullableString(json, 'email'),
      fullName: _nullableString(json, 'full_name'),
      avatarUrl: _nullableString(json, 'avatar_url'),
      createdAt: _dateTime(json, 'created_at'),
      updatedAt: _dateTime(json, 'updated_at'),
    );
  }

  Map<String, dynamic> toInsertJson(String userId) => {
    'id': userId,
    'email': email,
    'full_name': fullName,
    'avatar_url': avatarUrl,
  };

  Map<String, dynamic> toUpdateJson() => {
    if (email != null) 'email': email,
    if (fullName != null) 'full_name': fullName,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
  };
}

final class CategoryRecord {
  const CategoryRecord({
    required this.id,
    required this.userId,
    required this.name,
    this.normalizedName,
    required this.type,
    this.color,
    this.icon,
    this.hidden = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? normalizedName;
  final String type;
  final String? color;
  final String? icon;
  final bool hidden;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CategoryRecord.fromJson(Map<String, dynamic> json) {
    return CategoryRecord(
      id: _string(json, 'id'),
      userId: _string(json, 'user_id'),
      name: _string(json, 'name'),
      normalizedName: _nullableString(json, 'normalized_name'),
      type: _string(json, 'type'),
      color: _nullableString(json, 'color'),
      icon: _nullableString(json, 'icon'),
      hidden: _optionalBool(json, 'hidden'),
      createdAt: _dateTime(json, 'created_at'),
      updatedAt: _dateTime(json, 'updated_at'),
    );
  }

  Map<String, dynamic> toInsertJson(String userId) => {
    'user_id': userId,
    'name': name,
    if (normalizedName != null) 'normalized_name': normalizedName,
    'type': type,
    'color': color,
    'icon': icon,
    'hidden': hidden,
  };

  Map<String, dynamic> toUpdateJson() => {
    'name': name,
    if (normalizedName != null) 'normalized_name': normalizedName,
    'type': type,
    'color': color,
    'icon': icon,
    'hidden': hidden,
  };
}

final class BudgetRecord {
  const BudgetRecord({
    required this.id,
    required this.userId,
    required this.name,
    this.categoryId,
    this.categoryKey,
    required this.amount,
    required this.period,
    this.startDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? categoryId;
  final String? categoryKey;
  final double amount;
  final String period;
  final DateTime? startDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory BudgetRecord.fromJson(Map<String, dynamic> json) {
    return BudgetRecord(
      id: _string(json, 'id'),
      userId: _string(json, 'user_id'),
      name: _string(json, 'name'),
      categoryId: _nullableString(json, 'category_id'),
      categoryKey: _nullableString(json, 'category_key'),
      amount: _money(json, 'amount'),
      period: _string(json, 'period'),
      startDate: _nullableDate(json, 'start_date'),
      createdAt: _dateTime(json, 'created_at'),
      updatedAt: _dateTime(json, 'updated_at'),
    );
  }

  Map<String, dynamic> toInsertJson(String userId) => {
    'user_id': userId,
    'name': name,
    if (categoryId != null) 'category_id': categoryId,
    if (categoryKey != null) 'category_key': categoryKey,
    'amount': amount,
    'period': period,
    'start_date': startDate?.toIso8601String().split('T').first,
  };

  Map<String, dynamic> toUpdateJson() => {
    'name': name,
    if (categoryId != null) 'category_id': categoryId,
    if (categoryKey != null) 'category_key': categoryKey,
    'amount': amount,
    'period': period,
    'start_date': startDate?.toIso8601String().split('T').first,
  };
}

final class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.userId,
    required this.accountId,
    this.categoryId,
    required this.amount,
    required this.type,
    this.financialRole,
    this.description,
    required this.date,
    this.merchant,
    required this.importedFromCsv,
    this.importId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String accountId;
  final String? categoryId;
  final double amount;
  final String type;
  final String? financialRole;
  final String? description;
  final DateTime date;
  final String? merchant;
  final bool importedFromCsv;
  final String? importId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      id: _string(json, 'id'),
      userId: _string(json, 'user_id'),
      accountId: _string(json, 'account_id'),
      categoryId: _nullableString(json, 'category_id'),
      amount: _money(json, 'amount'),
      type: _string(json, 'type'),
      financialRole: _nullableString(json, 'financial_role'),
      description: _nullableString(json, 'description'),
      date: _date(json, 'date'),
      merchant: _nullableString(json, 'merchant'),
      importedFromCsv: _bool(json, 'imported_from_csv'),
      importId: _nullableString(json, 'import_id'),
      createdAt: _dateTime(json, 'created_at'),
      updatedAt: _dateTime(json, 'updated_at'),
    );
  }

  Map<String, dynamic> toInsertJson(String userId) => {
    'user_id': userId,
    'account_id': accountId,
    'category_id': categoryId,
    'amount': amount,
    'type': type,
    'financial_role': ?financialRole,
    'description': description,
    'date': date.toIso8601String().split('T').first,
    'merchant': merchant,
    'imported_from_csv': importedFromCsv,
    'import_id': importId,
  };

  Map<String, dynamic> toUpdateJson() => {
    'account_id': accountId,
    'category_id': categoryId,
    'amount': amount,
    'type': type,
    'financial_role': ?financialRole,
    'description': description,
    'date': date.toIso8601String().split('T').first,
    'merchant': merchant,
    'imported_from_csv': importedFromCsv,
    'import_id': importId,
  };
}

final class UserUsageDailyRollupRecord {
  const UserUsageDailyRollupRecord({
    required this.userId,
    required this.usageDate,
    required this.surface,
    required this.feature,
    required this.channel,
    required this.provider,
    required this.model,
    required this.eventType,
    required this.eventCount,
    required this.successCount,
    required this.failureCount,
    required this.totalDurationMs,
    required this.totalLatencyMs,
    this.avgLatencyMs,
    required this.totalUnitCount,
    required this.estimatedCostCents,
    required this.voiceMinutes,
    required this.updatedAt,
  });

  final String userId;
  final DateTime usageDate;
  final String surface;
  final String feature;
  final String channel;
  final String provider;
  final String model;
  final String eventType;
  final int eventCount;
  final int successCount;
  final int failureCount;
  final int totalDurationMs;
  final int totalLatencyMs;
  final double? avgLatencyMs;
  final double totalUnitCount;
  final double estimatedCostCents;
  final double voiceMinutes;
  final DateTime updatedAt;

  factory UserUsageDailyRollupRecord.fromJson(Map<String, dynamic> json) {
    return UserUsageDailyRollupRecord(
      userId: _string(json, 'user_id'),
      usageDate: _date(json, 'usage_date'),
      surface: _string(json, 'surface'),
      feature: _string(json, 'feature'),
      channel: _string(json, 'channel'),
      provider: _string(json, 'provider'),
      model: _string(json, 'model'),
      eventType: _string(json, 'event_type'),
      eventCount: _int(json, 'event_count'),
      successCount: _int(json, 'success_count'),
      failureCount: _int(json, 'failure_count'),
      totalDurationMs: _int(json, 'total_duration_ms'),
      totalLatencyMs: _int(json, 'total_latency_ms'),
      avgLatencyMs: _nullableDouble(json, 'avg_latency_ms'),
      totalUnitCount: _double(json, 'total_unit_count'),
      estimatedCostCents: _double(json, 'estimated_cost_cents'),
      voiceMinutes: _double(json, 'voice_minutes'),
      updatedAt: _dateTime(json, 'updated_at'),
    );
  }
}

final class UserUsagePeriodRollupRecord {
  const UserUsagePeriodRollupRecord({
    required this.userId,
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
    required this.surface,
    required this.feature,
    required this.channel,
    required this.provider,
    required this.model,
    required this.eventType,
    required this.eventCount,
    required this.successCount,
    required this.failureCount,
    required this.totalDurationMs,
    required this.totalLatencyMs,
    this.avgLatencyMs,
    required this.totalUnitCount,
    required this.estimatedCostCents,
    required this.voiceMinutes,
  });

  final String userId;
  final String periodType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String surface;
  final String feature;
  final String channel;
  final String provider;
  final String model;
  final String eventType;
  final int eventCount;
  final int successCount;
  final int failureCount;
  final int totalDurationMs;
  final int totalLatencyMs;
  final double? avgLatencyMs;
  final double totalUnitCount;
  final double estimatedCostCents;
  final double voiceMinutes;

  factory UserUsagePeriodRollupRecord.fromJson(Map<String, dynamic> json) {
    return UserUsagePeriodRollupRecord(
      userId: _string(json, 'user_id'),
      periodType: _string(json, 'period_type'),
      periodStart: _date(json, 'period_start'),
      periodEnd: _date(json, 'period_end'),
      surface: _string(json, 'surface'),
      feature: _string(json, 'feature'),
      channel: _string(json, 'channel'),
      provider: _string(json, 'provider'),
      model: _string(json, 'model'),
      eventType: _string(json, 'event_type'),
      eventCount: _int(json, 'event_count'),
      successCount: _int(json, 'success_count'),
      failureCount: _int(json, 'failure_count'),
      totalDurationMs: _int(json, 'total_duration_ms'),
      totalLatencyMs: _int(json, 'total_latency_ms'),
      avgLatencyMs: _nullableDouble(json, 'avg_latency_ms'),
      totalUnitCount: _double(json, 'total_unit_count'),
      estimatedCostCents: _double(json, 'estimated_cost_cents'),
      voiceMinutes: _double(json, 'voice_minutes'),
    );
  }
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Missing or invalid "$key".');
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Invalid "$key".');
}

bool _bool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Missing or invalid "$key".');
}

bool _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return false;
  if (value is bool) return value;
  throw FormatException('Invalid "$key".');
}

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Missing or invalid "$key".');
}

double _double(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Missing or invalid "$key".');
}

double? _nullableDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  throw FormatException('Invalid "$key".');
}

double _money(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Missing or invalid "$key".');
}

DateTime _dateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return DateTime.parse(value);
  throw FormatException('Missing or invalid "$key".');
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return DateTime.parse(value);
  throw FormatException('Missing or invalid "$key".');
}

DateTime? _nullableDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return DateTime.parse(value);
  throw FormatException('Invalid "$key".');
}
