import 'package:clarity/features/profile/domain/assistant_proposal_settings.dart';

final class ProfileRecord {
  const ProfileRecord({
    required this.id,
    this.email,
    this.fullName,
    this.avatarPath,
    this.preferredLocale,
    this.assistantSettings = const AssistantProposalSettings(),
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? email;
  final String? fullName;

  /// Object path in the private `avatars` bucket, never a URL.
  ///
  /// The only URL that loads it is signed and expires, so one cannot be stored.
  final String? avatarPath;

  final String? preferredLocale;
  final AssistantProposalSettings assistantSettings;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProfileRecord.fromJson(Map<String, dynamic> json) {
    return ProfileRecord(
      id: _string(json, 'id'),
      email: _nullableString(json, 'email'),
      fullName: _nullableString(json, 'full_name'),
      avatarPath: _nullableString(json, 'avatar_path'),
      preferredLocale: _nullableString(json, 'preferred_locale'),
      assistantSettings: AssistantProposalSettings.fromJson(
        json['assistant_settings'] as Map<String, dynamic>?,
      ),
      createdAt: _dateTime(json, 'created_at'),
      updatedAt: _dateTime(json, 'updated_at'),
    );
  }

  Map<String, dynamic> toInsertJson(String userId) => {
    'id': userId,
    'email': email,
    'full_name': fullName,
    'avatar_path': avatarPath,
    if (preferredLocale != null) 'preferred_locale': preferredLocale,
  };

  Map<String, dynamic> toUpdateJson() => {
    if (email != null) 'email': email,
    if (fullName != null) 'full_name': fullName,
    if (avatarPath != null) 'avatar_path': avatarPath,
    if (preferredLocale != null) 'preferred_locale': preferredLocale,
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
    this.source = 'manual',
    this.pending = false,
    this.removedAt,
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
  final String source;
  final bool pending;
  final DateTime? removedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    final importedFromCsv = _bool(json, 'imported_from_csv');
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
      importedFromCsv: importedFromCsv,
      importId: _nullableString(json, 'import_id'),
      source:
          _nullableString(json, 'source') ??
          (importedFromCsv ? 'csv' : 'manual'),
      pending: _optionalBool(json, 'pending'),
      removedAt: _nullableDate(json, 'removed_at'),
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
    if (financialRole != null) 'financial_role': financialRole,
    'description': description,
    'date': date.toIso8601String().split('T').first,
    'merchant': merchant,
    'imported_from_csv': importedFromCsv,
    'import_id': importId,
    'source': source,
    'pending': pending,
  };

  Map<String, dynamic> toUpdateJson() => {
    'account_id': accountId,
    'category_id': categoryId,
    'amount': amount,
    'type': type,
    if (financialRole != null) 'financial_role': financialRole,
    'description': description,
    'date': date.toIso8601String().split('T').first,
    'merchant': merchant,
    'imported_from_csv': importedFromCsv,
    'import_id': importId,
    'source': source,
    'pending': pending,
  };
}

final class UserVoiceSummaryRecord {
  const UserVoiceSummaryRecord({
    required this.userId,
    required this.usageDate,
    required this.voiceSeconds,
    required this.llmCalls,
    required this.sttSeconds,
    required this.ttsSeconds,
  });

  final String userId;
  final DateTime usageDate;
  final double voiceSeconds;
  final int llmCalls;
  final double sttSeconds;
  final double ttsSeconds;

  factory UserVoiceSummaryRecord.fromJson(Map<String, dynamic> json) {
    return UserVoiceSummaryRecord(
      userId: _string(json, 'user_id'),
      usageDate: _date(json, 'usage_date'),
      voiceSeconds: _double(json, 'voice_seconds'),
      llmCalls: _int(json, 'llm_calls'),
      sttSeconds: _double(json, 'stt_seconds'),
      ttsSeconds: _double(json, 'tts_seconds'),
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

DateTime _calendarDateFromSupabase(String trimmed) {
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
    final parts = trimmed.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
      12,
    );
  }

  final parsed = DateTime.parse(trimmed);
  final local = parsed.isUtc ? parsed.toLocal() : parsed;
  return DateTime(local.year, local.month, local.day, 12);
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return _calendarDateFromSupabase(value.trim());
  }
  throw FormatException('Missing or invalid "$key".');
}

DateTime? _nullableDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) {
    return _calendarDateFromSupabase(value.trim());
  }
  throw FormatException('Invalid "$key".');
}
