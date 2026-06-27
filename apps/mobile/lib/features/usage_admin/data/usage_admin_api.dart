import 'dart:convert';

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_models.dart';
import 'package:http/http.dart' as http;

class UsageAdminApi {
  UsageAdminApi({
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

  Future<bool> fetchOwnerAccess() async {
    final response = await _apiClient.get('/usage/admin/access');
    if (response.statusCode == 403) {
      return false;
    }
    if (response.statusCode != 200) {
      throw UsageAdminApiException(
        'Could not verify usage admin access (${response.statusCode}).',
      );
    }
    final data = _decodeMap(response);
    return data['authorized'] == true;
  }

  Future<OwnerPlatformSummary> fetchPlatformSummary() async {
    final response = await _apiClient.get('/usage/admin/summary');
    _ensureOwnerOk(response);
    return OwnerPlatformSummary.fromJson(_decodeMap(response));
  }

  Future<List<OwnerUserUsage>> fetchAllUsers() async {
    final response = await _apiClient.get('/usage/admin/users');
    _ensureOwnerOk(response);
    final data = _decodeMap(response);
    final users = data['users'];
    if (users is! List) {
      return const [];
    }
    return users
        .whereType<Map<String, dynamic>>()
        .map(OwnerUserUsage.fromJson)
        .toList(growable: false);
  }

  Future<OwnerUserDailyUsage> fetchUserDaily(
    String userId, {
    DateTime? start,
    DateTime? end,
  }) async {
    final query = <String, String>{};
    if (start != null) {
      query['start'] = _dateString(start);
    }
    if (end != null) {
      query['end'] = _dateString(end);
    }
    final response = await _apiClient.get(
      '/usage/admin/users/$userId/daily',
      query: query.isEmpty ? null : query,
    );
    _ensureOwnerOk(response);
    return OwnerUserDailyUsage.fromJson(_decodeMap(response));
  }

  void _ensureOwnerOk(http.Response response) {
    if (response.statusCode == 403) {
      throw const UsageAdminApiException('Owner usage access required.');
    }
    if (response.statusCode != 200) {
      throw UsageAdminApiException(
        'Usage admin request failed (${response.statusCode}).',
      );
    }
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const UsageAdminApiException('Invalid usage admin response.');
    }
    return data;
  }

  String _dateString(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

class UsageAdminApiException implements Exception {
  const UsageAdminApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
