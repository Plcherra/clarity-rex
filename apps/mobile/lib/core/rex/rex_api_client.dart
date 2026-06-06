import 'dart:convert';

import 'package:http/http.dart' as http;

import 'rex_auth_headers.dart';
import 'rex_config.dart';

final class RexApiClient {
  RexApiClient({
    http.Client? httpClient,
    String? baseUrl,
    RexAuthHeaders? authHeaders,
  }) : _httpClient = httpClient ?? http.Client(),
       _authHeaders = authHeaders ?? const RexAuthHeaders(),
       _baseUrl = (baseUrl ?? RexConfig.backendBaseUrl).replaceAll(
         RegExp(r'/$'),
         '',
       );

  final http.Client _httpClient;
  final RexAuthHeaders _authHeaders;
  final String _baseUrl;

  Uri uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('$_baseUrl$path');
    if (query == null || query.isEmpty) {
      return base;
    }
    return base.replace(queryParameters: query);
  }

  Uri webSocketUri(String path) {
    final baseUri = Uri.parse(_baseUrl);
    final scheme = switch (baseUri.scheme) {
      'https' => 'wss',
      'http' => 'ws',
      'wss' || 'ws' => baseUri.scheme,
      _ => throw const RexAuthException(
        'Clarity API URL must use http, https, ws, or wss.',
      ),
    };

    return baseUri.replace(
      scheme: scheme,
      path: '${baseUri.path.replaceAll(RegExp(r'/$'), '')}$path',
      query: null,
    );
  }

  Map<String, String> authHeaders([
    Map<String, String> baseHeaders = const {},
  ]) {
    return _authHeaders.headers(baseHeaders);
  }

  Future<http.Response> get(String path, {Map<String, String>? query}) {
    return _httpClient.get(uri(path, query), headers: _authHeaders.headers());
  }

  Future<http.Response> postJson(String path, Map<String, dynamic> body) {
    return _httpClient.post(
      uri(path),
      headers: _authHeaders.headers({'Content-Type': 'application/json'}),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> post(String path) {
    return _httpClient.post(uri(path), headers: _authHeaders.headers());
  }

  Future<http.Response> patchJson(String path, Map<String, dynamic> body) {
    return _httpClient.patch(
      uri(path),
      headers: _authHeaders.headers({'Content-Type': 'application/json'}),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> delete(String path) {
    return _httpClient.delete(uri(path), headers: _authHeaders.headers());
  }

  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_authHeaders.headers());
    return _httpClient.send(request);
  }
}
