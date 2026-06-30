import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:clarity/core/rex/rex_api_client.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';

part 'memory_saved_api.dart';
part 'memory_structured_api.dart';

final memoryApiProvider = Provider<MemoryApi>((ref) => MemoryApi());

abstract class _MemoryApiTransport {
  RexApiClient get _apiClient;

  Future<Map<String, dynamic>> _patchJson(
    String path,
    Map<String, dynamic> body,
  );

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  );

  Future<void> _delete(String path);

  Future<List<Map<String, dynamic>>> _getList(
    String path,
    Map<String, String> query,
  );

  dynamic _decodeResponse(http.Response response);

  String _dateOnly(DateTime value);

  Map<String, dynamic> _withoutNulls(Map<String, dynamic> values);
}

class MemoryApi extends _MemoryApiTransport
    with _SavedMemoryApi, _StructuredMemoryApi {
  MemoryApi({
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

  @override
  final RexApiClient _apiClient;

  @override
  Future<Map<String, dynamic>> _patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _apiClient.patchJson(path, body);
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const MemoryApiException('Backend returned an invalid response.');
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _apiClient.postJson(path, body);
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw const MemoryApiException('Backend returned an invalid response.');
    }
    return data;
  }

  @override
  Future<void> _delete(String path) async {
    final response = await _apiClient.delete(path);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MemoryApiException(
        _errorMessage(response.body),
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> _getList(
    String path,
    Map<String, String> query,
  ) async {
    final response = await _apiClient.get(path, query: query);
    final data = _decodeResponse(response);

    if (data is! List) {
      throw const MemoryApiException('Backend returned an invalid response.');
    }

    return data.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  @override
  dynamic _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MemoryApiException(
        _errorMessage(response.body),
        statusCode: response.statusCode,
      );
    }

    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const MemoryApiException(
        'Backend returned an unreadable response.',
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
          return 'Request could not be processed.';
        }
      }
    } on FormatException {
      return 'Backend returned an unreadable error.';
    }

    return 'Clarity API returned an error.';
  }

  @override
  String _dateOnly(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  @override
  Map<String, dynamic> _withoutNulls(Map<String, dynamic> values) {
    final body = <String, dynamic>{};
    for (final entry in values.entries) {
      final value = entry.value;
      if (value != null) {
        body[entry.key] = value;
      }
    }
    return body;
  }
}

class MemoryApiException implements Exception {
  const MemoryApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
