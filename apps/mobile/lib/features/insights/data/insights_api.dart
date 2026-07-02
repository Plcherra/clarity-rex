import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import '../domain/insight_item.dart';

final insightsApiProvider = Provider<InsightsApi>((ref) => InsightsApi());

class InsightsApiException implements Exception {
  const InsightsApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InsightSyncResult {
  const InsightSyncResult({
    required this.skipped,
    this.reason,
    this.created = 0,
    this.updated = 0,
    this.totalGenerated = 0,
  });

  final bool skipped;
  final String? reason;
  final int created;
  final int updated;
  final int totalGenerated;

  factory InsightSyncResult.fromJson(Map<String, dynamic> json) {
    return InsightSyncResult(
      skipped: json['skipped'] as bool? ?? false,
      reason: json['reason'] as String?,
      created: json['created'] as int? ?? 0,
      updated: json['updated'] as int? ?? 0,
      totalGenerated: json['total_generated'] as int? ?? 0,
    );
  }
}

class InsightsApi {
  InsightsApi({
    http.Client? client,
    String? baseUrl,
    RexAuthHeaders? authHeaders,
    RexApiClient? apiClient,
  }) : _apiClient =
           apiClient ??
           RexApiClient(
             httpClient: client,
             baseUrl: baseUrl,
             authHeaders: authHeaders,
           );

  final RexApiClient _apiClient;

  Future<List<InsightItem>> listInsights({int limit = 50}) async {
    final response = await _apiClient.get(
      '/insights',
      query: {'limit': limit.toString()},
    );
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const InsightsApiException('Invalid insights list response.');
    }
    final items = data['items'];
    if (items is! List) {
      throw const InsightsApiException('Invalid insights list payload.');
    }
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) InsightItem.fromJson(item),
    ];
  }

  Future<InsightSyncResult> syncInsights({
    Map<String, dynamic>? financialContext,
    List<Map<String, dynamic>>? accountabilitySignals,
  }) async {
    final payload = <String, dynamic>{};
    if (financialContext != null) {
      payload['financial_context'] = financialContext;
    }
    if (accountabilitySignals != null) {
      payload['accountability_signals'] = accountabilitySignals;
    }
    final response = await _apiClient.postJson('/insights/sync', payload);
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const InsightsApiException('Invalid insights sync response.');
    }
    return InsightSyncResult.fromJson(data);
  }

  Future<InsightItem> markRead(String insightId) async {
    final response = await _apiClient.patchJson('/insights/$insightId/read', {});
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const InsightsApiException('Invalid mark-read response.');
    }
    return InsightItem.fromJson(data);
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw InsightsApiException(_errorMessage(response.body));
    }
    if (response.body.trim().isEmpty) return null;
    return jsonDecode(response.body);
  }

  String _errorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }
      }
    } on FormatException {
      return 'Backend returned an unreadable error.';
    }
    return 'Clarity API returned an error.';
  }
}
