import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/rex/accountability/data/accountability_models.dart';

final accountabilityApiProvider = Provider<AccountabilityApi>(
  (ref) => AccountabilityApi(),
);

class AccountabilityApi {
  AccountabilityApi({
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

  Future<AccountabilityOverview> getOverview({
    int limit = 25,
    Map<String, dynamic>? budgetPerformance,
  }) async {
    final query = <String, String>{'limit': limit.toString()};
    if (budgetPerformance != null && budgetPerformance.isNotEmpty) {
      query['budget_performance'] = jsonEncode(budgetPerformance);
    }
    final response = await _apiClient.get(
      '/accountability/overview',
      query: query,
    );
    final data = _decodeResponse(response);

    if (data is! Map<String, dynamic>) {
      throw const AccountabilityApiException(
        'Backend returned an invalid accountability response.',
      );
    }

    return AccountabilityOverview.fromJson(data);
  }

  Future<PlanRecord> createPlan({
    required String title,
    String? description,
  }) async {
    final response = await _apiClient.postJson('/plans', {
      'plan_type': 'personal',
      'title': title,
      'description': description,
      'desired_outcome': description?.trim().isNotEmpty == true
          ? description
          : title,
      'priority': 4,
      'status': 'active',
      'active': true,
      'metadata': {'source': 'goals_tab'},
    });
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const AccountabilityApiException(
        'Backend returned an invalid plan response.',
      );
    }
    return PlanRecord.fromJson(data);
  }

  Future<PlanRecord> updatePlan(
    String planId, {
    String? title,
    String? description,
    int? priority,
    String? status,
    String? targetDateIso,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) {
      payload['title'] = title;
    }
    if (description != null) {
      payload['description'] = description;
      payload['desired_outcome'] = description;
    }
    if (priority != null) {
      payload['priority'] = priority;
    }
    if (status != null) {
      payload['status'] = status;
    }
    if (targetDateIso != null) {
      payload['target_date'] = targetDateIso;
    }
    final response = await _apiClient.patchJson('/plans/$planId', payload);
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const AccountabilityApiException(
        'Backend returned an invalid plan response.',
      );
    }
    return PlanRecord.fromJson(data);
  }

  Future<void> archivePlan(String planId) async {
    final response = await _apiClient.delete('/plans/$planId');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AccountabilityApiException(_errorMessage(response.body));
    }
  }

  Future<OpenThread> createOpenThread({
    required String title,
    String? summary,
  }) async {
    final response = await _apiClient.postJson('/open-threads', {
      'title': title,
      'summary': summary,
      'status': 'active',
      'source': 'user_created',
      'metadata': {'source': 'goals_tab'},
    });
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const AccountabilityApiException(
        'Backend returned an invalid open thread response.',
      );
    }
    return OpenThread.fromJson(data);
  }

  Future<OpenThread> updateOpenThread(
    String threadId, {
    String? title,
    String? summary,
    String? status,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) {
      payload['title'] = title;
    }
    if (summary != null) {
      payload['summary'] = summary;
    }
    if (status != null) {
      payload['status'] = status;
    }
    final response = await _apiClient.patchJson('/open-threads/$threadId', payload);
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const AccountabilityApiException(
        'Backend returned an invalid open thread response.',
      );
    }
    return OpenThread.fromJson(data);
  }

  Future<void> closeOpenThread(String threadId) async {
    final response = await _apiClient.delete('/open-threads/$threadId');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AccountabilityApiException(_errorMessage(response.body));
    }
  }

  Future<OpenThread> pauseOpenThread(String threadId) async {
    return updateOpenThread(threadId, status: 'paused');
  }

  Future<Commitment> createCommitment({
    required String title,
    required String commitmentText,
    String commitmentType = 'task',
  }) async {
    final response = await _apiClient.postJson('/commitments', {
      'commitment_type': commitmentType,
      'title': title,
      'commitment_text': commitmentText,
      'priority': commitmentType == 'habit' ? 5 : 4,
      'status': 'open',
      'active': true,
      'metadata': {
        'source': 'goals_tab',
        if (_isMorningRoutine(commitmentText)) 'routine': 'morning',
      },
    });
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const AccountabilityApiException(
        'Backend returned an invalid commitment response.',
      );
    }
    return Commitment.fromJson(data);
  }

  Future<Commitment> updateCommitment(
    String commitmentId, {
    String? title,
    String? commitmentText,
    int? priority,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) {
      payload['title'] = title;
    }
    if (commitmentText != null) {
      payload['commitment_text'] = commitmentText;
    }
    if (priority != null) {
      payload['priority'] = priority;
    }
    final response =
        await _apiClient.patchJson('/commitments/$commitmentId', payload);
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const AccountabilityApiException(
        'Backend returned an invalid commitment response.',
      );
    }
    return Commitment.fromJson(data);
  }

  Future<Commitment> completeCommitment(String commitmentId) async {
    final response = await _apiClient.patchJson('/commitments/$commitmentId', {
      'status': 'completed',
      'active': false,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
      'last_checked_at': DateTime.now().toUtc().toIso8601String(),
    });
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const AccountabilityApiException(
        'Backend returned an invalid commitment response.',
      );
    }
    return Commitment.fromJson(data);
  }

  Future<Commitment> missCommitment(String commitmentId) async {
    final response = await _apiClient.patchJson('/commitments/$commitmentId', {
      'status': 'missed',
      'active': false,
      'last_checked_at': DateTime.now().toUtc().toIso8601String(),
    });
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const AccountabilityApiException(
        'Backend returned an invalid commitment response.',
      );
    }
    return Commitment.fromJson(data);
  }

  Future<void> archiveCommitment(String commitmentId) async {
    final response = await _apiClient.delete('/commitments/$commitmentId');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AccountabilityApiException(_errorMessage(response.body));
    }
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AccountabilityApiException(_errorMessage(response.body));
    }

    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const AccountabilityApiException(
        'Backend returned an unreadable accountability response.',
      );
    }
  }

  String _errorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }
        if (detail is List && detail.isNotEmpty) {
          return 'Accountability request could not be processed.';
        }
      }
    } on FormatException {
      return 'Backend returned an unreadable accountability error.';
    }

    return 'Clarity API returned an accountability error.';
  }
}

bool _isMorningRoutine(String text) {
  final normalized = text.toLowerCase();
  return normalized.contains('wake') ||
      normalized.contains('5 am') ||
      normalized.contains('5:00') ||
      normalized.contains('morning routine');
}

class AccountabilityApiException implements Exception {
  const AccountabilityApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
