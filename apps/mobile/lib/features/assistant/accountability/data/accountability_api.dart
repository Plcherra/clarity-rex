import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/features/assistant/accountability/data/accountability_models.dart';

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

  Future<AccountabilityOverview> getOverview({int limit = 25}) async {
    final response = await _apiClient.get(
      '/accountability/overview',
      query: {'limit': limit.toString()},
    );
    final data = _decodeResponse(response);

    if (data is! Map<String, dynamic>) {
      throw const AccountabilityApiException(
        'Backend returned an invalid accountability response.',
      );
    }

    return AccountabilityOverview.fromJson(data);
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

    return 'Rex backend returned an accountability error.';
  }
}

class AccountabilityApiException implements Exception {
  const AccountabilityApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
