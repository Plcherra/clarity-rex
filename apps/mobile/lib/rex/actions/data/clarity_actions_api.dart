import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';

final clarityActionsApiProvider = Provider<ClarityActionsApi>(
  (ref) => ClarityActionsApi(),
);

class ClarityActionsApiException implements Exception {
  const ClarityActionsApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class ClarityActionResult {
  const ClarityActionResult({
    required this.action,
    required this.status,
    required this.result,
  });

  final String action;
  final String status;
  final List<Map<String, dynamic>> result;

  factory ClarityActionResult.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    return ClarityActionResult(
      action: _text(json['action']),
      status: _text(json['status']),
      result: rawResult is List
          ? [
              for (final item in rawResult)
                if (item is Map<String, dynamic>) item,
            ]
          : const [],
    );
  }
}

final class ClarityActionsApi {
  ClarityActionsApi({
    RexApiClient? apiClient,
    String? baseUrl,
    RexAuthHeaders? authHeaders,
  }) : _apiClient =
           apiClient ??
           RexApiClient(baseUrl: baseUrl, authHeaders: authHeaders);

  final RexApiClient _apiClient;

  Future<ClarityActionResult> execute({
    required String action,
    required Map<String, dynamic> payload,
    required bool confirmed,
  }) async {
    try {
      final response = await _apiClient.postJson('/clarity/actions', {
        'action': action,
        'payload': payload,
        'confirmed': confirmed,
      });
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ClarityActionsApiException(_errorMessage(response.body));
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ClarityActionsApiException(
          'Assistant returned an unreadable action result.',
        );
      }
      return ClarityActionResult.fromJson(decoded);
    } on RexAuthException catch (error) {
      throw ClarityActionsApiException(error.message);
    } on ClarityActionsApiException {
      rethrow;
    } on Object {
      throw const ClarityActionsApiException(
        'Could not apply the Clarity action.',
      );
    }
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
      // Keep the fallback below.
    }
    return 'Could not apply the Clarity action.';
  }
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
