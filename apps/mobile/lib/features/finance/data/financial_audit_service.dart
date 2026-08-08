import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/rex/rex_api_client.dart';
import '../../../core/rex/rex_auth_headers.dart';
import '../../../core/supabase/supabase_exceptions.dart';
import '../../../core/supabase/supabase_service.dart';

final class FinancialAuditEventInput {
  const FinancialAuditEventInput({
    required this.eventType,
    required this.entityType,
    this.entityId,
    this.source = 'app',
    this.previousValue = const <String, dynamic>{},
    this.newValue = const <String, dynamic>{},
    this.metadata = const <String, dynamic>{},
  });

  final String eventType;
  final String entityType;
  final String? entityId;
  final String source;
  final Map<String, dynamic> previousValue;
  final Map<String, dynamic> newValue;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toApiJson() => {
    'event_type': eventType.trim(),
    'entity_type': entityType.trim(),
    if (entityId?.trim().isNotEmpty == true) 'entity_id': entityId!.trim(),
    'source': source.trim().isEmpty ? 'app' : source.trim(),
    'previous_value': previousValue,
    'new_value': newValue,
    'metadata': metadata,
  };
}

final class FinancialAuditEvent {
  const FinancialAuditEvent({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.entityType,
    this.entityId,
    required this.source,
    required this.previousValue,
    required this.newValue,
    required this.metadata,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String eventType;
  final String entityType;
  final String? entityId;
  final String source;
  final Map<String, dynamic> previousValue;
  final Map<String, dynamic> newValue;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  factory FinancialAuditEvent.fromJson(Map<String, dynamic> json) {
    return FinancialAuditEvent(
      id: _string(json, 'id'),
      userId: _string(json, 'user_id'),
      eventType: _string(json, 'event_type'),
      entityType: _string(json, 'entity_type'),
      entityId: _nullableString(json, 'entity_id'),
      source: _string(json, 'source'),
      previousValue: _jsonMap(json['previous_value']),
      newValue: _jsonMap(json['new_value']),
      metadata: _jsonMap(json['metadata']),
      createdAt: _dateTime(json, 'created_at'),
    );
  }
}

final class FinancialAuditService {
  FinancialAuditService({
    required SupabaseService supabaseService,
    RexApiClient? apiClient,
    String? baseUrl,
    RexAuthHeaders? authHeaders,
  }) : _supabaseService = supabaseService,
       _apiClient =
           apiClient ??
           RexApiClient(baseUrl: baseUrl, authHeaders: authHeaders);

  final SupabaseService _supabaseService;
  final RexApiClient _apiClient;

  User get _currentUser {
    final user = _supabaseService.auth.currentUser;
    if (user == null) throw const SupabaseAuthRequiredException();
    return user;
  }

  Future<void> recordEvent(FinancialAuditEventInput input) async {
    _currentUser;
    if (input.eventType.trim().isEmpty || input.entityType.trim().isEmpty) {
      throw const SupabaseDataException(
        table: 'financial_audit_events',
        action: 'recordEvent',
        message: 'Audit event type and entity type are required.',
      );
    }

    try {
      final response = await _apiClient.postJson(
        '/finance/audit-events',
        input.toApiJson(),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SupabaseDataException(
          table: 'financial_audit_events',
          action: 'recordEvent',
          message: _errorMessage(response.body),
        );
      }
    } on SupabaseDataException {
      rethrow;
    } on RexAuthException catch (e) {
      throw SupabaseDataException(
        table: 'financial_audit_events',
        action: 'recordEvent',
        message: e.message,
        cause: e,
      );
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'financial_audit_events',
        action: 'recordEvent',
        message: 'Could not record financial audit event.',
        cause: e,
      );
    }
  }

  Future<List<FinancialAuditEvent>> fetchRecent({
    String? entityType,
    String? entityId,
    int limit = 25,
    DateTime? since,
  }) async {
    final user = _currentUser;
    try {
      dynamic query = _supabaseService.client
          .from('financial_audit_events')
          .select()
          .eq('user_id', user.id);
      final type = entityType?.trim();
      if (type != null && type.isNotEmpty) {
        query = query.eq('entity_type', type);
      }
      final id = entityId?.trim();
      if (id != null && id.isNotEmpty) {
        query = query.eq('entity_id', id);
      }
      if (since != null) {
        query = query.gte('created_at', since.toUtc().toIso8601String());
      }
      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit.clamp(1, 100).toInt());
      return rows
          .map<FinancialAuditEvent>(FinancialAuditEvent.fromJson)
          .toList(growable: false);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'financial_audit_events',
        action: 'fetchRecent',
        message: 'Could not fetch financial audit events.',
        cause: e,
      );
    }
  }
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value is Map<String, dynamic>) return Map.unmodifiable(value);
  if (value is Map) {
    return Map.unmodifiable(value.map((key, value) => MapEntry('$key', value)));
  }
  return const <String, dynamic>{};
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

DateTime _dateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return DateTime.parse(value);
  throw FormatException('Missing or invalid "$key".');
}

String _errorMessage(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
    }
  } on Object {
    // Fall through to generic message.
  }
  return 'Could not record financial audit event.';
}
