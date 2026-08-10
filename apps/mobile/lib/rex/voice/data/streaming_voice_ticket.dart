import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:clarity/rex/voice/data/voice_websocket.dart';

/// Fetch a short-lived single-use ticket over HTTPS, then use it on the
/// WebSocket URL. Prefer this over Authorization headers on the socket —
/// some mobile runtimes drop custom WS headers, so the stream never reaches
/// uvicorn and voice silently falls back to REST.
Future<String> fetchVoiceStreamTicket(
  Uri wsUri,
  Map<String, String>? headers, {
  http.Client? httpClient,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final client = httpClient ?? http.Client();
  final ownsClient = httpClient == null;
  try {
    final httpScheme = switch (wsUri.scheme) {
      'wss' => 'https',
      'ws' => 'http',
      _ => wsUri.scheme,
    };
    final ticketUri = wsUri.replace(
      scheme: httpScheme,
      path: '${wsUri.path}/ticket',
      query: '',
    );
    final response = await client
        .post(ticketUri, headers: headers ?? const {})
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const StreamingVoiceApiException(
        'Could not open Assistant voice stream. Check your connection and try again.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const StreamingVoiceApiException(
        'Could not open Assistant voice stream. Check your connection and try again.',
      );
    }
    final ticket = (decoded['ticket'] as String?)?.trim() ?? '';
    if (ticket.isEmpty) {
      throw const StreamingVoiceApiException(
        'Could not open Assistant voice stream. Check your connection and try again.',
      );
    }
    return ticket;
  } on StreamingVoiceApiException {
    rethrow;
  } on Object {
    throw const StreamingVoiceApiException(
      'Could not open Assistant voice stream. Check your connection and try again.',
    );
  } finally {
    if (ownsClient) {
      client.close();
    }
  }
}

Uri voiceStreamUriWithTicket(Uri wsUri, String ticket) {
  return wsUri.replace(
    queryParameters: {...wsUri.queryParameters, 'ticket': ticket},
  );
}
